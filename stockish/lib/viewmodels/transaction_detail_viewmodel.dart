import 'package:flutter/foundation.dart';
import '../models/transaction_item.dart';
import '../repositories/transaction_item_repository.dart';
import '../services/database/database_service.dart';

class TransactionDetailViewModel extends ChangeNotifier {
  final String referenceNumber;
  final String token;
  final TransactionItemRepository _itemRepository = TransactionItemRepository();

  TransactionDetailViewModel({required this.referenceNumber, required this.token});

  List<TransactionItem> _items = [];
  List<TransactionItem> get items => _items;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  int get pendingCount =>
      _items.where((i) => i.status == ItemStatus.pending).length;
  int get completeCount =>
      _items.where((i) => i.status == ItemStatus.complete).length;
  int get partialCount =>
      _items.where((i) => i.status == ItemStatus.partial).length;

  Future<void> loadItems() async {
    _isLoading = true;
    notifyListeners();
    _items = await _itemRepository.getItems(referenceNumber, token);
    _isLoading = false;
    notifyListeners();
  }

  /// 23 Juli 2026 — processedByNik: NIK operator yang sedang login.
  /// 29 Juli 2026 — tambah processedByName: nama operator yang sama,
  /// dikirim BERSAMAAN, tidak pernah salah satu doang.
  ///
  /// 🔧 (18 Agustus 2026) — return type BERUBAH dari `Future<bool>` jadi
  /// `Future<String?>` (null = sukses, non-null = pesan error spesifik untuk
  /// ditampilkan langsung ke operator). Alasan: sekarang ada 2 constraint
  /// beda (Outstanding vs Stock Tersedia) yang butuh pesan berbeda — caller
  /// (Screen) sebelumnya cuma dapat `bool`, terpaksa nebak pesan generik
  /// sendiri. Tidak breaking untuk caller lain yang tidak cek return value
  /// (mis. _handleNotReceived() di Screen, cuma `await` tanpa dipakai).
  Future<String?> saveItem(
    TransactionItem item,
    int quantity,
    String processedByNik,
    String processedByName,
  ) async {
    if (quantity < 0 || quantity > item.referenceQuantity) {
      return 'Quantity tidak boleh melebihi ${item.referenceQuantity} ${item.uom}.';
    }

    // 🆕 (18 Agustus 2026) — validasi stock tersedia, CUMA jalan kalau
    // availableStock terisi (backend cuma isi ini untuk Intransit — barang
    // keluar, mengurangi stock. Receiving = barang masuk, backend kirim
    // null, validasi ini otomatis ke-skip — tidak perlu ViewModel tahu tipe
    // dokumen secara eksplisit, murni data-driven). Lihat 05_Decision_Log.md
    // 18 Agustus 2026 & TransactionItemResponse.java (backend).
    final available = item.availableStock;
    if (available != null && quantity > available) {
      return 'Quantity tidak boleh melebihi stock tersedia ($available ${item.uom}).';
    }

    item.actualQuantity = quantity;
    item.isProcessed = true;
    item.processedByNik = processedByNik;
    item.processedByName = processedByName;

    await DatabaseService().saveProgress(
      referenceNumber: referenceNumber,
      itemCode: item.itemCode,
      actualQuantity: item.actualQuantity ?? 0,
      isProcessed: item.isProcessed,
      processedByNik: processedByNik,
      processedByName: processedByName,
    );

    notifyListeners();
    return null;
  }
}