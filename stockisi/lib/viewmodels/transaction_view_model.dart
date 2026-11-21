import 'package:flutter/foundation.dart';

import '../data/repositories/draft_repository.dart';
import '../data/repositories/reference_document_repository.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/repository_exceptions.dart';
import '../data/transaction_rules.dart';
import '../models/document_type.dart';
import '../models/draft.dart';
import '../models/reference_document.dart';
import '../models/transaction_record.dart';
import '../services/qr_payload.dart';

enum TransactionLoadState {
  loading,
  ready,

  /// Gagal memuat (koneksi). Bisa dicoba lagi.
  error,

  /// Dokumen tidak ada di gudang operator.
  notFound,

  /// Dokumen sudah SUBMITTED saat dibuka (diselesaikan operator lain).
  /// Draf, kalau ada, sudah dibuang.
  alreadySubmitted,

  /// Ada draf, tetapi dokumennya berubah sejak draf disimpan. Draf sudah
  /// dibuang.
  staleDraft,
}

/// Hasil pencocokan kode (scan atau input manual) ke item dokumen.
class ItemLookup {
  final ReferenceDocumentItem? item;
  final String? error;
  const ItemLookup.found(ReferenceDocumentItem this.item) : error = null;
  const ItemLookup.rejected(String this.error) : item = null;
}

/// State satu transaksi dari Detail sampai Ringkasan.
///
/// Diadaptasi dari `stockish/lib/viewmodels/transaction_detail_viewmodel.dart`
/// (hitungan status, validasi yang mengembalikan pesan spesifik) dan
/// `transaction_summary_viewmodel.dart` (`submit(asPartial)`). Bedanya:
/// scan/manual menambah jumlah, ubah dari kartu mengganti, ada tanda
/// "Tidak tersedia", dan draf disimpan lewat [DraftRepository].
class TransactionViewModel extends ChangeNotifier {
  final String documentNumber;
  final String warehouseCode;
  final ReferenceDocumentRepository _documents;
  final DraftRepository _drafts;
  final TransactionRepository _transactions;

  TransactionViewModel({
    required this.documentNumber,
    required this.warehouseCode,
    required this._documents,
    required this._drafts,
    required this._transactions,
  });

  TransactionLoadState _state = TransactionLoadState.loading;
  String? _loadError;
  ReferenceDocument? _document;
  Map<String, DraftLine> _lines = {};
  bool _dirty = false;
  bool _hadDraft = false;
  bool _submitting = false;
  bool _disposed = false;
  String vendorDeliveryNo = '';

  TransactionLoadState get state => _state;
  String? get loadError => _loadError;
  ReferenceDocument get document => _document!;
  bool get isReceiving => _document?.type == DocumentType.receiving;
  List<ReferenceDocumentItem> get items => _document?.items ?? const [];
  Map<String, DraftLine> get lines => Map.unmodifiable(_lines);
  DraftLine? lineOf(String itemCode) => _lines[itemCode];

  /// Ada perubahan yang belum disimpan sebagai draf.
  bool get isDirty => _dirty;

  /// Dokumen dibuka dari draf yang tersimpan.
  bool get resumedFromDraft => _hadDraft;
  bool get submitting => _submitting;

  ItemStatus statusOf(ReferenceDocumentItem item) =>
      itemStatusOf(item, _lines[item.itemCode]);

  /// Item yang masih perlu diperiksa (sisa > 0).
  List<ReferenceDocumentItem> get processableItems =>
      items.where((i) => !i.isFulfilled).toList();

  int countOf(ItemStatus status) =>
      items.where((i) => statusOf(i) == status).length;

  /// "x dari y item diperiksa": item yang tidak lagi Pending.
  int get checkedCount =>
      processableItems.where((i) => statusOf(i) != ItemStatus.pending).length;

  int get partialCount =>
      _document == null ? 0 : partialCountOf(document, _lines);

  // ---------------------------------------------------------------- muat

  Future<void> load() async {
    _loadError = null;
    // Pemuatan pertama dipanggil dari initState saat state sudah
    // `loading`; memberi tahu listener di tengah build tidak diizinkan.
    if (_state != TransactionLoadState.loading) {
      _state = TransactionLoadState.loading;
      _notify();
    }
    try {
      final doc = await _documents.getDocument(documentNumber);
      final draft = await _drafts.getDraft(documentNumber);
      _document = doc;
      if (!doc.isOpen) {
        if (draft != null) await _drafts.deleteDraft(documentNumber);
        _state = TransactionLoadState.alreadySubmitted;
      } else if (draft != null && draft.basedOnVersion != doc.version) {
        await _drafts.deleteDraft(documentNumber);
        _state = TransactionLoadState.staleDraft;
      } else {
        _hadDraft = draft != null;
        // Baris untuk item yang sudah terpenuhi diabaikan.
        _lines = {
          for (final e in (draft?.lines ?? const <String, DraftLine>{}).entries)
            if (doc.items.any((i) => i.itemCode == e.key && !i.isFulfilled))
              e.key: e.value,
        };
        _dirty = false;
        _state = TransactionLoadState.ready;
      }
    } on NotFoundException {
      _state = TransactionLoadState.notFound;
    } on RepositoryException catch (e) {
      _loadError = e.message;
      _state = TransactionLoadState.error;
    }
    _notify();
  }

  // ------------------------------------------------------- cocokkan kode

  ReferenceDocumentItem? _itemByCode(String code) {
    final c = code.trim().toLowerCase();
    for (final i in items) {
      if (i.itemCode.toLowerCase() == c) return i;
    }
    return null;
  }

  ItemLookup _lookupCode(String code) {
    final item = _itemByCode(code);
    if (item == null) {
      return ItemLookup.rejected(
          'Barang ${code.trim().toUpperCase()} tidak ada di dokumen $documentNumber.');
    }
    if (item.isFulfilled) {
      return ItemLookup.rejected(
          '${item.itemCode} sudah terpenuhi di transaksi sebelumnya.');
    }
    return ItemLookup.found(item);
  }

  /// Mencocokkan isi QR mentah ke item dokumen. Ditolak kalau format
  /// salah, barang milik gudang lain, satuan berbeda, barang tidak ada di
  /// dokumen, atau sudah terpenuhi.
  ItemLookup lookupScan(String raw) {
    final qr = QrPayload.tryParse(raw);
    if (qr == null) {
      return const ItemLookup.rejected(
          'QR tidak dikenali. Pastikan yang dipindai adalah label barang '
          'Stockisi.');
    }
    if (qr.warehouseCode.toUpperCase() != warehouseCode.toUpperCase()) {
      return ItemLookup.rejected(
          'Barang ini milik gudang ${qr.warehouseCode}, bukan gudang Anda '
          '($warehouseCode).');
    }
    final result = _lookupCode(qr.itemCode);
    final item = result.item;
    if (item != null && item.uom.toUpperCase() != qr.uom.toUpperCase()) {
      return ItemLookup.rejected(
          'Satuan di label (${qr.uom}) berbeda dengan satuan dokumen '
          '(${item.uom}).');
    }
    return result;
  }

  /// Mencocokkan kode barang yang diketik manual.
  ItemLookup lookupManual(String code) {
    if (code.trim().isEmpty) {
      return const ItemLookup.rejected('Kode barang wajib diisi.');
    }
    return _lookupCode(code);
  }

  // ---------------------------------------------------------------- input

  /// Scan atau input manual: menambah jumlah. Item bertanda "Tidak
  /// tersedia" mulai lagi dari 0. Mengembalikan pesan kalau ditolak.
  String? addQuantity(ReferenceDocumentItem item, int quantity) {
    if (quantity <= 0) return 'Kuantitas harus lebih dari 0.';
    final line = _lines[item.itemCode];
    final current =
        (line == null || line.markedUnavailable) ? 0 : line.quantity;
    return _apply(item, current + quantity);
  }

  /// Ubah dari kartu item: mengganti jumlah.
  String? setQuantity(ReferenceDocumentItem item, int quantity) =>
      _apply(item, quantity);

  String? _apply(ReferenceDocumentItem item, int total) {
    if (item.isFulfilled) return 'Item ini sudah terpenuhi.';
    final violation = checkQuantity(item, total);
    if (violation != null) return violation.message;
    _lines[item.itemCode] =
        DraftLine(itemCode: item.itemCode, quantity: total);
    _changed();
    return null;
  }

  /// Hapus input atau batalkan tanda "Tidak tersedia": item kembali Pending.
  void clearItem(ReferenceDocumentItem item) {
    if (_lines.remove(item.itemCode) != null) _changed();
  }

  /// Tandai "Tidak tersedia" (kuantitas 0, status Partial). Hanya untuk
  /// item yang belum punya input.
  void markUnavailable(ReferenceDocumentItem item) {
    if (item.isFulfilled || _lines.containsKey(item.itemCode)) return;
    _lines[item.itemCode] = DraftLine(
        itemCode: item.itemCode, quantity: 0, markedUnavailable: true);
    _changed();
  }

  void _changed() {
    _dirty = true;
    _notify();
  }

  // ----------------------------------------------------------------- draf

  /// Menyimpan input sebagai draf. Kalau input kosong, draf lama dibuang.
  Future<void> saveDraft() async {
    if (_lines.isEmpty) {
      await _drafts.deleteDraft(documentNumber);
    } else {
      await _drafts.saveDraft(Draft(
        documentNumber: documentNumber,
        basedOnVersion: document.version,
        lines: Map.of(_lines),
        updatedAt: DateTime.now(),
      ));
    }
    _dirty = false;
    _hadDraft = _lines.isNotEmpty;
    _notify();
  }

  Future<void> discardDraft() async {
    await _drafts.deleteDraft(documentNumber);
    _lines = {};
    _dirty = false;
    _hadDraft = false;
    _notify();
  }

  // --------------------------------------------------------------- submit

  /// Pemeriksaan syarat submit di sisi layar (repository memeriksa ulang).
  SubmitCheck? checkBeforeSubmit() => checkSubmit(
        document: document,
        lines: _lines,
        vendorDeliveryNo: isReceiving ? vendorDeliveryNo : null,
      );

  /// Melempar `SubmitException` atau `DataUnavailableException` dari
  /// repository apa adanya.
  Future<TransactionRecord> submit(SubmitMode mode) async {
    if (_submitting) throw StateError('Submit sedang berjalan');
    _submitting = true;
    _notify();
    try {
      final record = await _transactions.submit(SubmitRequest(
        documentNumber: documentNumber,
        basedOnVersion: document.version,
        lines: Map.of(_lines),
        vendorDeliveryNo: isReceiving ? vendorDeliveryNo.trim() : null,
        mode: mode,
      ));
      _dirty = false;
      return record;
    } finally {
      _submitting = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
