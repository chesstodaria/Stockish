// lib/viewmodels/print_qr_viewmodel.dart (REPLACE FULL — filter hasQrCode=true, 20 Agustus 2026)
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:barcode/barcode.dart';
import '../models/stock_item.dart';
import '../models/user.dart';
import '../models/print_job.dart';
import '../repositories/stock_card_repository.dart';
import '../repositories/audit_log_repository.dart';
import '../repositories/print_job_repository.dart';
import '../utils/device_identifier.dart';

class PrintQrViewModel extends ChangeNotifier {
  final StockCardRepository _repository = StockCardRepository();
  final AuditLogRepository _auditLogRepository = AuditLogRepository();
  final PrintJobRepository _printJobRepository = PrintJobRepository();
  final User user;

  PrintQrViewModel({required this.user});

  List<StockItem> _allItems = [];
  List<StockItem> _filteredItems = [];
  final Set<String> _selectedItemCodes = {};
  bool _isLoading = true;
  bool _isGenerating = false;
  String _searchQuery = '';

  // 🆕 (11 Agustus 2026) — state Print via Jaringan, independen dari
  // isGenerating (dialog print Android biasa) supaya kedua tombol bisa
  // punya loading indicator masing-masing tanpa saling ganggu.
  bool _isSubmittingNetworkPrint = false;
  List<PrintJob> _recentJobs = [];
  bool _isLoadingJobs = false;

  DateTime? _lastRefreshTime;
  DateTime? get lastRefreshTime => _lastRefreshTime;

  List<StockItem> get filteredItems => _filteredItems;
  Set<String> get selectedItemCodes => _selectedItemCodes;
  int get selectedCount => _selectedItemCodes.length;
  bool get isLoading => _isLoading;
  bool get isGenerating => _isGenerating;
  bool get isSubmittingNetworkPrint => _isSubmittingNetworkPrint;
  List<PrintJob> get recentJobs => _recentJobs;
  bool get isLoadingJobs => _isLoadingJobs;

  /// 🆕🔧 (20 Agustus 2026) — FIX: filter `hasQrCode == true` ditambahkan
  /// di sini (ViewModel), BUKAN di `StockCardRepository.searchItems()` —
  /// repository itu dipakai BARENG Digital Stock Card yang justru butuh
  /// nampilin SEMUA item apa pun status QR-nya (keperluan cek stok, bukan
  /// cetak label). Sebelumnya Print QR menampilkan SELURUH item warehouse
  /// tanpa peduli `hasQrCode` — item yang belum/tidak lagi punya QR
  /// (mis. di-reset manual, atau memang belum pernah di-generate lewat
  /// Admin "Generate QR Code") ikut muncul di list "reprint", padahal
  /// belum ada QR resmi untuk di-reprint. Fix ini menyelaraskan Print QR
  /// dengan namanya sendiri — cuma nampilin item yang SUDAH pernah
  /// digenerate QR-nya.
  Future<void> loadItems() async {
    _isLoading = true;
    notifyListeners();

    final items = await _repository.searchItems('', warehouseCode: user.warehouseCode, token: user.token);
    _allItems = items.where((item) => item.hasQrCode).toList(); // 🆕 — filter reprint-only
    _lastRefreshTime = DateTime.now();
    _isLoading = false;
    _applyFilter();
  }

  Future<void> refresh() => loadItems();

  void onSearchChanged(String query) {
    _searchQuery = query.trim().toLowerCase();
    _applyFilter();
  }

  void _applyFilter() {
    _filteredItems = _searchQuery.isEmpty
        ? _allItems
        : _allItems
            .where((item) =>
                item.itemCode.toLowerCase().contains(_searchQuery) ||
                item.itemName.toLowerCase().contains(_searchQuery))
            .toList();
    notifyListeners();
  }

  void toggleSelection(String itemCode) {
    if (_selectedItemCodes.contains(itemCode)) {
      _selectedItemCodes.remove(itemCode);
    } else {
      _selectedItemCodes.add(itemCode);
    }
    notifyListeners();
  }

  void selectAllFiltered() {
    _selectedItemCodes.addAll(_filteredItems.map((e) => e.itemCode));
    notifyListeners();
  }

  void clearSelection() {
    _selectedItemCodes.clear();
    notifyListeners();
  }

  Future<Uint8List?> generatePdfBytes() async {
    final selectedItems =
        _allItems.where((item) => _selectedItemCodes.contains(item.itemCode)).toList();
    if (selectedItems.isEmpty) return null;

    _isGenerating = true;
    notifyListeners();

    try {
      final bytes = await _generateLabelsPdf(selectedItems);

      // 🆕 (12 Agustus 2026) — DeviceIdentifier.getInfo() (3 komponen:
      // name/ip/id), bukan get() string gabungan lagi.
      await _auditLogRepository.addLog(
        userNik: user.nik,
        userName: user.userName,
        module: 'Print QR',
        activity: 'Cetak label QR untuk ${selectedItems.length} barang',
        device: await DeviceIdentifier.getInfo(),
        token: user.token,
        category: 'ITEM_RELATED',
        relatedItemCodes: selectedItems.map((item) => item.itemCode).toList(),
      );

      return bytes;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// 🆕 (11 Agustus 2026) — "Print via Jaringan". Reuse PDF generation yang
  /// sama persis (`_generateLabelsPdf`), cuma tujuannya beda: dikirim ke
  /// backend (Print Job Queue) alih-alih dibuka lewat dialog print Android.
  /// Return true kalau sukses terkirim (bukan sukses TERCETAK — itu baru
  /// diketahui belakangan lewat refreshJobStatus()). Throws kalau gagal,
  /// Screen yang tangkap & tampilkan SnackBar.
  Future<bool> submitNetworkPrint() async {
    final selectedItems =
        _allItems.where((item) => _selectedItemCodes.contains(item.itemCode)).toList();
    if (selectedItems.isEmpty) return false;

    if (user.warehouseCode.isEmpty) {
      throw Exception('Akun ini tidak terikat Warehouse — tidak bisa kirim print job.');
    }

    _isSubmittingNetworkPrint = true;
    notifyListeners();

    try {
      final bytes = await _generateLabelsPdf(selectedItems);

      // 🆕 (12 Agustus 2026) — DeviceIdentifier.getInfo(), lihat catatan di generatePdfBytes().
      await _auditLogRepository.addLog(
        userNik: user.nik,
        userName: user.userName,
        module: 'Print QR',
        activity: 'Kirim print job via jaringan untuk ${selectedItems.length} barang',
        device: await DeviceIdentifier.getInfo(),
        token: user.token,
        category: 'ITEM_RELATED',
        relatedItemCodes: selectedItems.map((item) => item.itemCode).toList(),
      );

      await _printJobRepository.submit(
        user: user,
        pdfBytes: bytes,
        itemCount: selectedItems.length,
      );

      await refreshJobStatus();
      return true;
    } finally {
      _isSubmittingNetworkPrint = false;
      notifyListeners();
    }
  }

  /// Cek status job terakhir milik NIK ini — dipanggil manual (tombol
  /// refresh), BUKAN polling otomatis (hemat baterai tablet).
  Future<void> refreshJobStatus() async {
    _isLoadingJobs = true;
    notifyListeners();
    try {
      _recentJobs = await _printJobRepository.getStatus(user);
    } finally {
      _isLoadingJobs = false;
      notifyListeners();
    }
  }

  Future<Uint8List> _generateLabelsPdf(List<StockItem> items) async {
    final doc = pw.Document();
    const perPage = 6;

    for (var i = 0; i < items.length; i += perPage) {
      final pageItems = items.skip(i).take(perPage).toList();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.GridView(
            crossAxisCount: 2,
            childAspectRatio: 1.4,
            children: pageItems.map((item) => _buildLabelCell(item)).toList(),
          ),
        ),
      );
    }
    return doc.save();
  }

  pw.Widget _buildLabelCell(StockItem item) {
    return pw.Container(
      margin: const pw.EdgeInsets.all(8),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            item.itemName,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            maxLines: 2,
          ),
          pw.SizedBox(height: 4),
          pw.BarcodeWidget(
            barcode: Barcode.qrCode(),
            data: item.itemCode,
            width: 90,
            height: 90,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            item.itemCode,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }
}