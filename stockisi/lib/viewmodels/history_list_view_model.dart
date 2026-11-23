import 'package:flutter/foundation.dart';

import '../data/repositories/transaction_repository.dart';
import '../data/repository_exceptions.dart';
import '../models/transaction_record.dart';

/// State tab Riwayat: daftar transaksi SUBMITTED di gudang operator,
/// terbaru dulu.
///
/// Tidak ada pencarian dan filter di sini. Laporan 2.2.6 hanya meminta
/// daftar transaksi beserta badge RCV/INT, dan CONTEXT 7 tidak menyebut
/// cabang pencarian untuk tab ini.
class HistoryListViewModel extends ChangeNotifier {
  final TransactionRepository _transactions;

  HistoryListViewModel(this._transactions);

  List<TransactionRecord>? _records;
  bool _loading = false;
  String? _error;
  int _loadSeq = 0;
  bool _disposed = false;

  /// Null selama pemuatan pertama belum selesai.
  List<TransactionRecord>? get records => _records;
  bool get loading => _loading;
  String? get error => _error;
  bool get isEmpty => _records?.isEmpty ?? false;

  /// [silent] dipakai saat kembali dari detail: daftar lama tetap tampil
  /// selama data baru dimuat.
  Future<void> load({bool silent = false}) async {
    final seq = ++_loadSeq;
    if (!silent || _records == null) {
      _loading = true;
      _error = null;
      _notify();
    }
    try {
      final list = await _transactions.getHistory();
      if (seq != _loadSeq) return;
      _records = list;
      _error = null;
    } on RepositoryException catch (e) {
      if (seq != _loadSeq) return;
      if (!silent || _records == null) _error = e.message;
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
