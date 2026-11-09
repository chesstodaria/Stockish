import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/activity_log.dart';
import '../models/reference_document.dart';
import '../repositories/activity_log_repository.dart';

enum ScopeFilter { mine, all }

class TransactionHistoryViewModel extends ChangeNotifier {
  final ActivityLogRepository _repository = ActivityLogRepository();
  final User user;

  // BARU (29 Juli 2026) — dipakai PerformaScreen (Supervisor) supaya
  // masuk Transaction History langsung dalam mode "Semua Operator", tanpa
  // perlu buka popup filter dulu. Default TETAP ScopeFilter.mine (Business
  // Rule "Punya Saya" sebagai default sistem TIDAK berubah — ini cuma
  // override titik masuk tertentu, bukan ganti default global).
  TransactionHistoryViewModel({required this.user, ScopeFilter? initialScope}) {
    if (initialScope != null) _scopeFilter = initialScope;
  }

  List<ActivityLog> _allLogs = [];
  List<ActivityLog> _filteredLogs = [];
  bool _isLoading = true;
  bool _hasError = false;
  DateTime? _lastRefreshTime;

  ScopeFilter _scopeFilter = ScopeFilter.mine;
  TransactionType? _typeFilter;
  DocumentStatus? _statusFilter;
  String _searchQuery = '';

  List<ActivityLog> get filteredLogs => _filteredLogs;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  DateTime? get lastRefreshTime => _lastRefreshTime;
  ScopeFilter get scopeFilter => _scopeFilter;
  TransactionType? get typeFilter => _typeFilter;
  DocumentStatus? get statusFilter => _statusFilter;

  int get activeFilterCount {
    var count = 0;
    if (_scopeFilter == ScopeFilter.all) count++;
    if (_typeFilter != null) count++;
    if (_statusFilter != null) count++;
    return count;
  }

  Future<void> loadLogs() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      _allLogs = await _repository.getLogsByWarehouse(user.warehouseCode, user.token);
      _lastRefreshTime = DateTime.now();
      _applyFilters();
    } catch (_) {
      _hasError = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadLogs();

  void onSearchChanged(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void applyFilter({
    required ScopeFilter scope,
    required TransactionType? type,
    required DocumentStatus? status,
  }) {
    _scopeFilter = scope;
    _typeFilter = type;
    _statusFilter = status;
    _applyFilters();
  }

  void _applyFilters() {
    _filteredLogs = _allLogs.where((log) {
      if (_scopeFilter == ScopeFilter.mine && log.submittedByNik != user.nik) {
        return false;
      }
      if (_typeFilter != null && log.type != _typeFilter) return false;
      if (_statusFilter != null && log.status != _statusFilter) return false;
      if (_searchQuery.isNotEmpty &&
          !log.referenceNumber.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
    _isLoading = false;
    notifyListeners();
  }
}