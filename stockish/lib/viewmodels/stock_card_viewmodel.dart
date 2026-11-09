import 'package:flutter/foundation.dart';
import '../models/stock_item.dart';
import '../repositories/stock_card_repository.dart';

/// 24 Juli 2026 — tambah token (dibutuhkan sejak repository terhubung ke
/// backend asli) + errorMessage (loadItems() sekarang bisa beneran gagal
/// karena network/server, bukan cuma delay mock yang selalu sukses).
class StockCardViewModel extends ChangeNotifier {
  final String warehouseCode;
  final String token;
  final StockCardRepository _repository = StockCardRepository();

  StockCardViewModel({required this.warehouseCode, required this.token});

  List<StockItem> _allItems = [];
  List<StockItem> _filteredItems = [];
  List<StockItem> get filteredItems => _filteredItems;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DateTime? _lastRefreshTime;
  DateTime? get lastRefreshTime => _lastRefreshTime;

  String _searchQuery = '';

  Future<void> loadItems() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allItems = await _repository.searchItems('', warehouseCode: warehouseCode, token: token);
      _lastRefreshTime = DateTime.now();
      _applyFilter();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _allItems = [];
      _filteredItems = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => loadItems();

  void onSearchChanged(String query) {
    _searchQuery = query;
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    if (_searchQuery.trim().isEmpty) {
      _filteredItems = List.from(_allItems);
      return;
    }
    final lower = _searchQuery.toLowerCase();
    _filteredItems = _allItems
        .where((i) => i.itemCode.toLowerCase().contains(lower) || i.itemName.toLowerCase().contains(lower))
        .toList();
  }
}