import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repositories/stock_card_repository.dart';
import '../data/repository_exceptions.dart';
import '../models/stock_item.dart';

/// State tab Kartu Stok: pencarian barang di gudang operator.
///
/// Pencarian dikerjakan repository, bukan disaring di klien, supaya nanti
/// sama perilakunya dengan kolom `ilike` di Supabase (CONTEXT 7: kolom
/// pencarian sebagai fokus utama).
class StockCardListViewModel extends ChangeNotifier {
  final StockCardRepository _stockCard;

  StockCardListViewModel(this._stockCard);

  static const _debounceDelay = Duration(milliseconds: 300);

  List<StockItem>? _items;
  String _query = '';
  bool _loading = false;
  String? _error;
  int _loadSeq = 0;
  Timer? _debounce;
  bool _disposed = false;

  /// Null selama pemuatan pertama belum selesai.
  List<StockItem>? get items => _items;
  String get query => _query;
  bool get loading => _loading;
  String? get error => _error;

  /// true kalau gudang operator belum punya barang sama sekali. Dihitung
  /// hanya saat kata kunci kosong, supaya hasil pencarian yang kosong tidak
  /// dilaporkan sebagai gudang kosong.
  bool get warehouseEmpty =>
      _query.trim().isEmpty && (_items?.isEmpty ?? false);

  /// true kalau ada kata kunci tetapi tidak ada barang yang cocok.
  bool get noMatch => _query.trim().isNotEmpty && (_items?.isEmpty ?? false);

  Future<void> load({bool silent = false}) async {
    final seq = ++_loadSeq;
    if (!silent || _items == null) {
      _loading = true;
      _error = null;
      _notify();
    }
    try {
      final list = await _stockCard.searchItems(_query);
      if (seq != _loadSeq) return;
      _items = list;
      _error = null;
    } on RepositoryException catch (e) {
      if (seq != _loadSeq) return;
      if (!silent || _items == null) _error = e.message;
    }
    _loading = false;
    _notify();
  }

  /// Memuat ulang dengan kata kunci baru. Pemuatan sebelumnya diabaikan
  /// lewat [_loadSeq], jadi hasil lama tidak menimpa hasil baru.
  ///
  /// Pencarian ditunda [_debounceDelay] supaya mengetik tidak memicu satu
  /// permintaan per huruf; [_loadSeq] tetap menjaga hasil yang datang
  /// terlambat.
  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    _notify();
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, load);
  }

  void clearQuery() {
    _debounce?.cancel();
    if (_query.isEmpty) return;
    _query = '';
    _notify();
    load();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
