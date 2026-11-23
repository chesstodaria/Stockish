import 'package:flutter/foundation.dart';

import '../data/repositories/stock_card_repository.dart';
import '../data/repository_exceptions.dart';
import '../models/stock_item.dart';
import '../models/stock_movement.dart';

/// State Detail Kartu Stok (layar 9): satu barang, saldonya, dan riwayat
/// mutasi dua kategori.
class StockCardDetailViewModel extends ChangeNotifier {
  final StockCardRepository _stockCard;
  final String itemCode;

  StockCardDetailViewModel(this._stockCard, this.itemCode);

  StockItem? _item;
  List<StockMovement>? _movements;
  bool _loading = false;
  String? _error;
  bool _notFound = false;
  bool _disposed = false;

  StockItem? get item => _item;

  /// Null selama pemuatan pertama belum selesai.
  List<StockMovement>? get movements => _movements;
  bool get loading => _loading;
  String? get error => _error;

  /// true kalau barang tidak ada atau bukan milik gudang operator.
  bool get notFound => _notFound;

  /// true kalau barang ada tetapi belum pernah ada mutasi.
  bool get hasNoMovements => _movements?.isEmpty ?? false;

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notFound = false;
    _notify();
    try {
      final item = await _stockCard.getItem(itemCode);
      final movements = await _stockCard.getMovements(itemCode);
      _item = item;
      _movements = movements;
    } on NotFoundException catch (e) {
      _notFound = true;
      _error = e.message;
    } on RepositoryException catch (e) {
      _error = e.message;
    }
    _loading = false;
    _notify();
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
