import '../../models/audit_event.dart';
import '../../models/document_claim.dart';
import '../../models/document_type.dart';
import '../../models/draft.dart';
import '../../models/operator_profile.dart';
import '../../models/reference_document.dart';
import '../../models/stock_item.dart';
import '../../models/stock_movement.dart';
import '../../models/transaction_record.dart';
import '../repositories/transaction_repository.dart';
import '../repository_exceptions.dart';
import '../transaction_rules.dart';

/// Area yang bisa dibuat gagal sekali untuk menguji state gagal + coba lagi.
/// Diaktifkan lewat `--dart-define=STOCKISI_MOCK_FAIL=documents,stockCard`.
enum MockArea { login, documents, drafts, submit, history, stockCard }

class MockAccount {
  final OperatorProfile profile;
  final String password;
  const MockAccount(this.profile, this.password);
}

class MockItem {
  final String code;
  final String name;
  final String uom;
  final String warehouseCode;
  final String rackNumber;
  const MockItem(this.code, this.name, this.uom, this.warehouseCode,
      this.rackNumber);
}

class MockDocumentLine {
  final String itemCode;
  final int ordered;
  int processed = 0;
  MockDocumentLine(this.itemCode, this.ordered);
}

class MockDocument {
  final String number;
  final DocumentType type;
  final String warehouseCode;
  final DateTime date;
  final String counterparty;
  final List<MockDocumentLine> lines;
  DocumentStatus status = DocumentStatus.open;
  int version = 0;

  MockDocument({
    required this.number,
    required this.type,
    required this.warehouseCode,
    required this.date,
    required this.counterparty,
    required this.lines,
  });
}

/// Penyimpanan di memori yang dibagi semua repository tiruan. Menegakkan
/// aturan bisnis CONTEXT bagian 6 lewat `transaction_rules.dart`.
class MockBackend {
  final Map<String, String> warehouses;
  final Map<String, MockAccount> accounts;
  final Map<String, MockItem> items;
  final Map<String, MockDocument> documents;

  /// Jeda buatan supaya state memuat ikut teruji. Nol di unit test.
  final Duration latency;

  final Set<MockArea> _failOnce;

  /// Dokumen yang akan "diselesaikan operator lain" tepat sebelum submit
  /// pertama ke dokumen itu. Nilai: NIK operator lain tersebut.
  final Map<String, String> contestedDocuments;

  final Map<String, int> balances = {};
  final Map<String, List<StockMovement>> movementsByItem = {};
  final List<TransactionRecord> transactions = [];

  /// Jejak aktivitas, urut waktu. Di Supabase ditulis trigger dan RPC,
  /// sehingga aplikasi hanya bisa membacanya.
  final List<AuditEvent> auditEvents = [];

  /// Klaim dokumen per nomor. Klaim kedaluwarsa dibersihkan saat dibaca.
  final Map<String, DocumentClaim> claims = {};

  /// Perangkat pemegang sesi per NIK.
  final Map<String, String> sessionDevices = {};

  /// Draf per NIK, lalu per nomor dokumen (mensimulasikan draf di perangkat).
  final Map<String, Map<String, Draft>> draftsByNik = {};

  OperatorProfile? currentOperator;
  int _transactionSeq = 0;

  MockBackend({
    required this.warehouses,
    required this.accounts,
    required this.items,
    required this.documents,
    this.latency = const Duration(milliseconds: 500),
    Set<MockArea> failOnce = const {},
    Map<String, String> contestedDocuments = const {},
  })  : _failOnce = {...failOnce},
        contestedDocuments = {...contestedDocuments};

  Future<void> delay([double factor = 1]) {
    if (latency == Duration.zero) return Future.value();
    return Future.delayed(latency * factor);
  }

  /// Membuat panggilan berikutnya ke [area] gagal sekali (untuk test).
  void failNext(MockArea area) => _failOnce.add(area);

  /// Melempar `DataUnavailableException` sekali untuk area yang diminta.
  void maybeFail(MockArea area) {
    if (_failOnce.remove(area)) throw const DataUnavailableException();
  }

  OperatorProfile requireOperator() {
    final op = currentOperator;
    if (op == null) throw const NotSignedInException();
    return op;
  }

  Map<String, Draft> draftsOf(String nik) =>
      draftsByNik.putIfAbsent(nik, () => {});

  ReferenceDocument toDocument(MockDocument doc) {
    return ReferenceDocument(
      number: doc.number,
      type: doc.type,
      warehouseCode: doc.warehouseCode,
      documentDate: doc.date,
      counterparty: doc.counterparty,
      status: doc.status,
      version: doc.version,
      items: [
        for (final line in doc.lines)
          ReferenceDocumentItem(
            itemCode: line.itemCode,
            itemName: items[line.itemCode]!.name,
            uom: items[line.itemCode]!.uom,
            rackNumber: items[line.itemCode]!.rackNumber,
            orderedQuantity: line.ordered,
            processedQuantity: line.processed,
            availableStock: doc.type == DocumentType.intransit
                ? (balances[line.itemCode] ?? 0)
                : null,
          ),
      ],
    );
  }

  StockItem toStockItem(MockItem item) {
    return StockItem(
      itemCode: item.code,
      itemName: item.name,
      uom: item.uom,
      warehouseCode: item.warehouseCode,
      rackNumber: item.rackNumber,
      balance: balances[item.code] ?? 0,
    );
  }

  /// Submit satu transaksi secara utuh. Semua pemeriksaan dilakukan sebelum
  /// ada data yang diubah, jadi kegagalan tidak meninggalkan perubahan.
  TransactionRecord applySubmit({
    required OperatorProfile operator,
    required SubmitRequest request,
    required DateTime at,
  }) {
    final doc = documents[request.documentNumber];
    if (doc == null || doc.warehouseCode != operator.warehouseCode) {
      throw const NotFoundException();
    }
    if (doc.status == DocumentStatus.submitted) {
      throw const SubmitException(SubmitFailure.documentAlreadySubmitted);
    }
    if (doc.version != request.basedOnVersion) {
      throw const SubmitException(SubmitFailure.documentChanged);
    }

    final current = toDocument(doc);
    final check = checkSubmit(
      document: current,
      lines: request.lines,
      vendorDeliveryNo: request.vendorDeliveryNo,
    );
    if (check != null) {
      throw SubmitException(SubmitFailure.rulesNotMet, check: check);
    }

    _transactionSeq++;
    final number = 'TRX-${doc.type.code}-${_yymmdd(at)}-'
        '${_transactionSeq.toString().padLeft(4, '0')}';

    final txLines = <TransactionLine>[];
    for (final item in current.items) {
      if (item.isFulfilled) continue;
      final input = request.lines[item.itemCode]!;
      final qty = input.markedUnavailable ? 0 : input.quantity;
      txLines.add(TransactionLine(
        itemCode: item.itemCode,
        itemName: item.itemName,
        uom: item.uom,
        rackNumber: item.rackNumber,
        quantity: qty,
        markedUnavailable: input.markedUnavailable,
      ));
      if (qty == 0) continue;

      doc.lines.firstWhere((l) => l.itemCode == item.itemCode).processed +=
          qty;
      final before = balances[item.itemCode] ?? 0;
      final after =
          doc.type == DocumentType.receiving ? before + qty : before - qty;
      balances[item.itemCode] = after;
      movementsByItem.putIfAbsent(item.itemCode, () => []).add(StockMovement(
            date: at,
            type: doc.type,
            quantity: qty,
            documentNumber: doc.number,
            transactionNumber: number,
            operatorNik: operator.nik,
            balanceAfter: after,
          ));
    }

    final allFulfilled = doc.lines.every((l) => l.processed >= l.ordered);
    final closes = request.mode == SubmitMode.close || allFulfilled;
    if (closes) doc.status = DocumentStatus.submitted;
    doc.version++;

    final record = TransactionRecord(
      number: number,
      documentNumber: doc.number,
      type: doc.type,
      warehouseCode: doc.warehouseCode,
      submittedAt: at,
      operatorNik: operator.nik,
      operatorName: operator.name,
      vendorDeliveryNo: doc.type == DocumentType.receiving
          ? request.vendorDeliveryNo!.trim()
          : null,
      closedDocument: closes,
      lines: txLines,
    );
    transactions.add(record);
    recordAudit(
      nik: operator.nik,
      action: 'submit',
      entity: 'transaction',
      entityId: number,
      summary: 'Submit ${doc.type.code} ${doc.number}: ${txLines.length} item, '
          '${closes ? 'dokumen ditutup' : 'dokumen tetap terbuka'}',
    );
    draftsOf(operator.nik).remove(doc.number);
    return record;
  }

  // ----------------------------------------------------------------- audit
  /// Masa berlaku klaim dokumen. Di Supabase dijaga juga oleh `pg_cron`
  /// yang membersihkan klaim kedaluwarsa.
  static const claimTtl = Duration(minutes: 5);

  void recordAudit({
    required String nik,
    required String action,
    required String entity,
    String? entityId,
    required String summary,
  }) {
    auditEvents.add(AuditEvent(
      at: DateTime.now(),
      actorNik: nik,
      action: action,
      entity: entity,
      entityId: entityId,
      summary: summary,
    ));
  }

  // ----------------------------------------------------------------- klaim
  /// Klaim aktif untuk satu dokumen, atau null kalau bebas atau kedaluwarsa.
  DocumentClaim? activeClaimOf(String documentNumber) {
    final claim = claims[documentNumber];
    if (claim == null) return null;
    if (claim.isExpiredAt(DateTime.now())) {
      claims.remove(documentNumber);
      return null;
    }
    return claim;
  }

  ClaimOutcome claimDocument(String documentNumber) {
    final operator = requireOperator();
    final existing = activeClaimOf(documentNumber);
    if (existing != null && existing.holderNik != operator.nik) {
      return ClaimOutcome(granted: false, claim: existing);
    }
    final now = DateTime.now();
    final claim = DocumentClaim(
      documentNumber: documentNumber,
      holderNik: operator.nik,
      holderName: operator.name,
      claimedAt: existing?.claimedAt ?? now,
      expiresAt: now.add(claimTtl),
    );
    claims[documentNumber] = claim;
    if (existing == null) {
      recordAudit(
        nik: operator.nik,
        action: 'claim',
        entity: 'reference_document',
        entityId: documentNumber,
        summary: 'Membuka dan mengunci $documentNumber',
      );
    }
    return ClaimOutcome(granted: true, claim: claim);
  }

  void releaseDocument(String documentNumber) {
    final operator = requireOperator();
    final claim = claims[documentNumber];
    if (claim == null || claim.holderNik != operator.nik) return;
    claims.remove(documentNumber);
    recordAudit(
      nik: operator.nik,
      action: 'release',
      entity: 'reference_document',
      entityId: documentNumber,
      summary: 'Melepas kunci $documentNumber',
    );
  }

  /// Klaim aktif milik operator lain di gudang yang sama.
  List<DocumentClaim> activeClaims() {
    final operator = requireOperator();
    final result = <DocumentClaim>[];
    for (final number in [...claims.keys]) {
      final claim = activeClaimOf(number);
      if (claim != null && claim.holderNik != operator.nik) result.add(claim);
    }
    return result;
  }

  // ------------------------------------------------------------------ sesi
  bool registerDevice(String nik, String deviceId, {bool force = false}) {
    final current = sessionDevices[nik];
    if (current != null && current != deviceId) {
      if (!force) return false;
      recordAudit(
        nik: nik,
        action: 'force_session',
        entity: 'session',
        summary: 'Sesi dipindahkan ke perangkat lain',
      );
    }
    sessionDevices[nik] = deviceId;
    return true;
  }

  void unregisterDevice(String nik, String deviceId) {
    if (sessionDevices[nik] == deviceId) sessionDevices.remove(nik);
  }

  static String _yymmdd(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.year % 100)}${two(d.month)}${two(d.day)}';
  }
}
