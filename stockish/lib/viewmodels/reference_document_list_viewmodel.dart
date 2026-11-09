// viewmodels/reference_document_list_viewmodel.dart (REPLACE FULL — 20 Agustus 2026,
// fix "used after being disposed" race condition ditemukan saat testing idle-timeout
// Skenario B: force-logout bisa dispose ViewModel ini SEBELUM operasi async yang masih
// jalan (loadDocuments/_loadUnfinishedItemCounts/_pollTick) selesai. Fix: guard _disposed
// + helper _safeNotify() menggantikan semua notifyListeners() langsung.)
import 'package:flutter/foundation.dart';
import '../models/reference_document.dart';
import '../models/transaction_item.dart';
import '../repositories/reference_document_repository.dart';
import '../repositories/transaction_item_repository.dart';
import '../services/poller.dart';

class ReferenceDocumentListViewModel extends ChangeNotifier {
  final ReferenceDocumentRepository _repository = ReferenceDocumentRepository();
  final TransactionItemRepository _itemRepository = TransactionItemRepository();

  final String _token;
  final String _warehouseName;

  final TransactionType? contextDefaultType;

  late final Poller _poller;

  // 🆕 (20 Agustus 2026) — flag hidup/mati ViewModel. Async callback (dari
  // await yang masih pending saat Screen di-dispose, mis. force-logout
  // idle-timeout) WAJIB cek ini sebelum notifyListeners() ATAU sebelum
  // menulis state lagi — instance yang sudah disposed tidak boleh disentuh.
  bool _disposed = false;

  ReferenceDocumentListViewModel({
    required String token,
    required String warehouseName,
    this.contextDefaultType,
  })  : _token = token,
        _warehouseName = warehouseName,
        _typeFilter = contextDefaultType {
    // 🆕 (7 Agustus 2026) — Targeted Auto-Refresh, Titik 1. Interval 15
    // detik, Scoped (start/stop dikontrol Screen, bukan otomatis di sini).
    _poller = Poller(interval: const Duration(seconds: 15), onTick: _pollTick);
  }

  List<ReferenceDocument> _allDocuments = [];
  List<ReferenceDocument> _filteredDocuments = [];
  bool _isLoading = true;

  bool _hasError = false;
  bool get hasError => _hasError;

  Map<String, int> _unfinishedItemCounts = {};

  DateTime? _lastSyncTime;

  String _searchQuery = '';
  TransactionType? _typeFilter;

  Set<DocumentStatus> _statusFilter = {
    DocumentStatus.available,
    DocumentStatus.partial,
    DocumentStatus.locked,
  };

  List<ReferenceDocument> get filteredDocuments => _filteredDocuments;
  bool get isLoading => _isLoading;
  TransactionType? get typeFilter => _typeFilter;
  Set<DocumentStatus> get statusFilter => _statusFilter;
  DateTime? get lastSyncTime => _lastSyncTime;

  int unfinishedItemCount(String referenceNumber) =>
      _unfinishedItemCounts[referenceNumber] ?? 0;

  // 🆕 (20 Agustus 2026) — satu-satunya jalur notifyListeners() di file
  // ini. Semua pemanggilan langsung notifyListeners() diganti ini.
  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> loadDocuments() async {
    _isLoading = true;
    _hasError = false;
    _safeNotify();

    try {
      final documents = await _repository.getList(_token, warehouseName: _warehouseName);
      if (_disposed) return; // 🆕 — Screen sudah pergi saat await selesai, hentikan di sini
      _allDocuments = documents;
      _lastSyncTime = DateTime.now();
      _applyFilters();
    } catch (e) {
      debugPrint('🔍[LOCK] loadDocuments gagal: $e');
      if (_disposed) return; // 🆕
      _allDocuments = [];
      _hasError = true;
      _applyFilters();
      _isLoading = false;
      _safeNotify();
      return;
    }

    if (_disposed) return; // 🆕
    _isLoading = false;
    _safeNotify();

    await _loadUnfinishedItemCounts(_allDocuments);
  }

  /// Realtime ERP Sync (Nomor 4, 5 Agustus 2026) — Refresh List sekarang
  /// trigger sync ERP dulu (SEMUA entity, terlepas dari filter tipe yang
  /// aktif), baru reload List. Sync best-effort — gagal sync TIDAK
  /// menghalangi reload.
  Future<void> refreshWithSync() async {
    await _repository.syncAllFromErp(_token);
    if (_disposed) return; // 🆕
    await loadDocuments();
  }

  /// 🆕 (7 Agustus 2026) — poll tick RINGAN. Beda dari loadDocuments():
  /// (1) TIDAK toggle _isLoading (tidak boleh kedip spinner tiap 15 detik),
  /// (2) SKIP fan-out badge "item belum selesai" untuk dokumen LAMA (mahal,
  /// jarang berubah) — Opsi B: dokumen yang GENUINELY BARU (belum ada di
  /// _allDocuments sebelumnya) tetap di-fetch badge-nya, supaya tidak
  /// nampilin "0 item belum selesai" yang salah untuk dokumen baru.
  Future<void> _pollTick() async {
    try {
      final documents = await _repository.getList(_token, warehouseName: _warehouseName);
      if (_disposed) return; // 🆕

      final oldRefNumbers = _allDocuments.map((d) => d.referenceNumber).toSet();
      final newlyAppeared = documents
          .where((d) => !oldRefNumbers.contains(d.referenceNumber))
          .toList();

      _allDocuments = documents;
      _lastSyncTime = DateTime.now();
      _applyFilters();

      if (newlyAppeared.isNotEmpty) {
        await _loadUnfinishedItemCounts(newlyAppeared, mergeIntoExisting: true);
      }
    } catch (e) {
      debugPrint('🔍[POLLER] List poll tick gagal (diabaikan): $e');
    }
  }

  Future<void> _loadUnfinishedItemCounts(
    List<ReferenceDocument> documents, {
    bool mergeIntoExisting = false,
  }) async {
    final entries = await Future.wait(documents.map((doc) async {
      try {
        final items = await _itemRepository.getItems(doc.referenceNumber, _token);
        final unfinished = items.where((i) => i.status != ItemStatus.complete).length;
        return MapEntry(doc.referenceNumber, unfinished);
      } catch (e) {
        debugPrint('🔍[LOCK] gagal hitung unfinished item untuk ${doc.referenceNumber}: $e');
        return MapEntry(doc.referenceNumber, 0);
      }
    }));

    if (_disposed) return; // 🆕 — inilah titik persis yang meledak di screenshot (baris notifyListeners() lama)

    if (mergeIntoExisting) {
      _unfinishedItemCounts = {..._unfinishedItemCounts, ...Map.fromEntries(entries)};
    } else {
      _unfinishedItemCounts = Map.fromEntries(entries);
    }
    _safeNotify();
  }

  void onSearchChanged(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void onTypeFilterChanged(TransactionType? type) {
    _typeFilter = type;
    _applyFilters();
  }

  void onStatusFilterChanged(Set<DocumentStatus> statuses) {
    _statusFilter = statuses;
    _applyFilters();
  }

  int _statusSortWeight(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.available:
        return 0;
      case DocumentStatus.partial:
        return 1;
      case DocumentStatus.locked:
        return 2;
      case DocumentStatus.completed:
        return 3;
    }
  }

  bool _isHiddenByAge(ReferenceDocument doc) {
    if (doc.status != DocumentStatus.completed) return false;
    if (doc.finalizedAt == null) return false;
    final age = DateTime.now().difference(doc.finalizedAt!);
    return age.inHours >= 24;
  }

  void _applyFilters() {
    final filtered = _allDocuments.where((doc) {
      if (_isHiddenByAge(doc)) return false;

      final matchesSearch =
          doc.referenceNumber.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesType = _typeFilter == null || doc.type == _typeFilter;
      final matchesStatus = _statusFilter.isEmpty || _statusFilter.contains(doc.status);
      return matchesSearch && matchesType && matchesStatus;
    }).toList();

    filtered.sort((a, b) =>
        _statusSortWeight(a.status).compareTo(_statusSortWeight(b.status)));

    _filteredDocuments = filtered;
    _safeNotify();
  }

  Future<LockResult> lockDocument(String referenceNumber) async {
    return await _repository.lockDocument(referenceNumber, _token);
  }

  DocumentStatus? getDocumentStatus(String referenceNumber) {
    final match = _allDocuments.where((d) => d.referenceNumber == referenceNumber);
    return match.isEmpty ? null : match.first.status;
  }

  void startPolling() => _poller.start();
  void stopPolling() => _poller.stop();
  void pausePolling() => _poller.stop();
  void resumePolling() => _poller.start();

  @override
  void dispose() {
    _disposed = true; // 🆕 — set DULUAN, sebelum apa pun lain, cegah race dengan callback async yang mendarat bertepatan dengan dispose()
    _poller.stop();
    super.dispose();
  }
}