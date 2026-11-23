import 'package:flutter/foundation.dart';

import '../data/repositories/transaction_repository.dart';
import '../data/repository_exceptions.dart';
import '../models/transaction_record.dart';

/// State Detail Riwayat Transaksi (layar 12).
class HistoryDetailViewModel extends ChangeNotifier {
  final TransactionRepository _transactions;
  final String number;

  HistoryDetailViewModel(this._transactions, this.number);

  TransactionRecord? _record;
  bool _loading = false;
  String? _error;
  bool _notFound = false;
  bool _disposed = false;

  TransactionRecord? get record => _record;
  bool get loading => _loading;
  String? get error => _error;

  /// true kalau transaksi tidak ada atau bukan milik gudang operator.
  bool get notFound => _notFound;

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notFound = false;
    _notify();
    try {
      _record = await _transactions.getTransaction(number);
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
