import '../../models/document_type.dart';
import '../../models/draft.dart';
import '../../models/operator_profile.dart';
import '../../models/reference_document.dart';
import '../../models/stock_item.dart';
import '../../models/stock_movement.dart';
import '../../models/transaction_record.dart';
import '../../services/session_store.dart';
import '../repositories/repositories.dart';
import '../repository_exceptions.dart';
import 'mock_backend.dart';

/// Implementasi tiruan semua kontrak repository di atas [MockBackend].
/// Sesi disimpan di [sessionStore] (perangkat), sedangkan data lain hidup di
/// memori dan kembali ke data awal setiap app dibuka ulang.
Repositories createMockRepositories(
  MockBackend backend, {
  SessionStore? sessionStore,
}) {
  return Repositories(
    auth: MockAuthRepository(backend, sessionStore ?? InMemorySessionStore()),
    documents: MockReferenceDocumentRepository(backend),
    drafts: MockDraftRepository(backend),
    transactions: MockTransactionRepository(backend),
    stockCard: MockStockCardRepository(backend),
  );
}

class MockAuthRepository implements AuthRepository {
  final MockBackend _b;
  final SessionStore _session;
  MockAuthRepository(this._b, this._session);

  @override
  Future<OperatorProfile> login(String nik, String password) async {
    await _b.delay(1.5);
    _b.maybeFail(MockArea.login);
    final account = _b.accounts[nik.trim()];
    if (account == null || account.password != password) {
      throw const AuthException(AuthFailure.invalidCredentials);
    }
    if (!account.profile.isActive) {
      throw const AuthException(AuthFailure.inactiveAccount);
    }
    await _session.writeNik(account.profile.nik);
    _b.currentOperator = account.profile;
    return account.profile;
  }

  @override
  Future<OperatorProfile?> restoreSession() async {
    await _b.delay(0.5);
    final nik = await _session.readNik();
    final account = nik == null ? null : _b.accounts[nik];
    // Akun yang sudah dihapus atau dinonaktifkan tidak boleh dipulihkan.
    if (account == null || !account.profile.isActive) {
      if (nik != null) await _session.clear();
      _b.currentOperator = null;
      return null;
    }
    _b.currentOperator = account.profile;
    return account.profile;
  }

  @override
  Future<void> logout() async {
    await _b.delay(0.5);
    await _session.clear();
    _b.currentOperator = null;
  }
}

class MockReferenceDocumentRepository implements ReferenceDocumentRepository {
  final MockBackend _b;
  MockReferenceDocumentRepository(this._b);

  @override
  Future<List<ReferenceDocument>> getDocuments(DocumentType type) async {
    await _b.delay();
    final op = _b.requireOperator();
    _b.maybeFail(MockArea.documents);
    final docs = _b.documents.values
        .where((d) => d.warehouseCode == op.warehouseCode && d.type == type)
        .map(_b.toDocument)
        .toList()
      ..sort((a, b) => b.documentDate.compareTo(a.documentDate));
    return docs;
  }

  @override
  Future<ReferenceDocument> getDocument(String number) async {
    await _b.delay();
    final op = _b.requireOperator();
    _b.maybeFail(MockArea.documents);
    final doc = _b.documents[number];
    if (doc == null || doc.warehouseCode != op.warehouseCode) {
      throw const NotFoundException();
    }
    return _b.toDocument(doc);
  }
}

class MockDraftRepository implements DraftRepository {
  final MockBackend _b;
  MockDraftRepository(this._b);

  @override
  Future<Draft?> getDraft(String documentNumber) async {
    await _b.delay(0.3);
    final op = _b.requireOperator();
    _b.maybeFail(MockArea.drafts);
    return _b.draftsOf(op.nik)[documentNumber];
  }

  @override
  Future<Set<String>> getDocumentNumbersWithDraft() async {
    await _b.delay(0.3);
    final op = _b.requireOperator();
    _b.maybeFail(MockArea.drafts);
    return _b.draftsOf(op.nik).keys.toSet();
  }

  @override
  Future<void> saveDraft(Draft draft) async {
    await _b.delay(0.3);
    final op = _b.requireOperator();
    _b.maybeFail(MockArea.drafts);
    _b.draftsOf(op.nik)[draft.documentNumber] = draft;
  }

  @override
  Future<void> deleteDraft(String documentNumber) async {
    await _b.delay(0.3);
    final op = _b.requireOperator();
    _b.draftsOf(op.nik).remove(documentNumber);
  }
}

class MockTransactionRepository implements TransactionRepository {
  final MockBackend _b;
  MockTransactionRepository(this._b);

  @override
  Future<TransactionRecord> submit(SubmitRequest request) async {
    await _b.delay(1.5);
    final op = _b.requireOperator();
    _b.maybeFail(MockArea.submit);

    // Simulasi "dokumen sudah diproses operator lain": operator lain
    // menyelesaikan seluruh sisa dokumen tepat sebelum submit ini.
    final otherNik = _b.contestedDocuments.remove(request.documentNumber);
    if (otherNik != null) _simulateOtherOperator(otherNik, request);

    try {
      return _b.applySubmit(
          operator: op, request: request, at: DateTime.now());
    } on SubmitException catch (e) {
      if (e.failure != SubmitFailure.rulesNotMet) {
        _b.draftsOf(op.nik).remove(request.documentNumber);
      }
      rethrow;
    }
  }

  void _simulateOtherOperator(String nik, SubmitRequest request) {
    final other = _b.accounts[nik]!.profile;
    final doc = _b.toDocument(_b.documents[request.documentNumber]!);
    _b.applySubmit(
      operator: other,
      request: SubmitRequest(
        documentNumber: doc.number,
        basedOnVersion: doc.version,
        lines: {
          for (final item in doc.items)
            item.itemCode: DraftLine(
                itemCode: item.itemCode, quantity: item.remainingQuantity),
        },
        vendorDeliveryNo: 'SJ-SIMULASI-${doc.number}',
        mode: SubmitMode.close,
      ),
      at: DateTime.now().subtract(const Duration(minutes: 3)),
    );
  }

  @override
  Future<List<TransactionRecord>> getHistory() async {
    await _b.delay();
    final op = _b.requireOperator();
    _b.maybeFail(MockArea.history);
    return _b.transactions
        .where((t) => t.warehouseCode == op.warehouseCode)
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  }

  @override
  Future<TransactionRecord> getTransaction(String number) async {
    await _b.delay(0.5);
    final op = _b.requireOperator();
    _b.maybeFail(MockArea.history);
    for (final t in _b.transactions) {
      if (t.number == number && t.warehouseCode == op.warehouseCode) return t;
    }
    throw const NotFoundException();
  }
}

class MockStockCardRepository implements StockCardRepository {
  final MockBackend _b;
  MockStockCardRepository(this._b);

  @override
  Future<List<StockItem>> searchItems(String query) async {
    await _b.delay();
    final op = _b.requireOperator();
    _b.maybeFail(MockArea.stockCard);
    final q = query.trim().toLowerCase();
    return _b.items.values
        .where((i) => i.warehouseCode == op.warehouseCode)
        .where((i) =>
            q.isEmpty ||
            i.code.toLowerCase().contains(q) ||
            i.name.toLowerCase().contains(q))
        .map(_b.toStockItem)
        .toList()
      ..sort((a, b) => a.itemCode.compareTo(b.itemCode));
  }

  @override
  Future<StockItem> getItem(String itemCode) async {
    await _b.delay(0.5);
    final op = _b.requireOperator();
    _b.maybeFail(MockArea.stockCard);
    final item = _b.items[itemCode];
    if (item == null || item.warehouseCode != op.warehouseCode) {
      throw const NotFoundException();
    }
    return _b.toStockItem(item);
  }

  @override
  Future<List<StockMovement>> getMovements(String itemCode) async {
    await _b.delay(0.5);
    final op = _b.requireOperator();
    _b.maybeFail(MockArea.stockCard);
    final item = _b.items[itemCode];
    if (item == null || item.warehouseCode != op.warehouseCode) {
      throw const NotFoundException();
    }
    final list = [...?_b.movementsByItem[itemCode]]
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }
}
