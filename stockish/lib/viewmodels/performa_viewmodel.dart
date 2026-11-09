import 'package:flutter/foundation.dart';
import '../models/performance_entry.dart';
import '../models/user.dart';
import '../repositories/activity_log_repository.dart';

enum DateRangePreset { last7Days, last30Days, thisMonth }

/// ViewModel untuk PerformaScreen — khusus accessMobileSupervisor.
/// Pola sama ViewModel lain di project: 1 instance per Screen, dibuat di
/// initState(), bukan singleton.
class PerformaViewModel extends ChangeNotifier {
  final ActivityLogRepository _repository = ActivityLogRepository();
  final User user;

  PerformaViewModel({required this.user});

  List<PerformanceEntry> _entries = [];
  bool _isLoading = true;
  bool _hasError = false;
  DateRangePreset _preset = DateRangePreset.last7Days;

  // Alfabetis by name (keputusan eksplisit user, 29 Juli 2026) — bukan
  // diurut dari jumlah transaksi terbanyak seperti draft awal.
  List<PerformanceEntry> get entries {
    final sorted = List<PerformanceEntry>.from(_entries);
    sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  DateRangePreset get preset => _preset;

  int get totalCompletedCount =>
      _entries.fold(0, (sum, e) => sum + e.completedCount);

  // Rata-rata waktu Transaksi keseluruhan — weighted average (bobot =
  // jumlah transaksi tiap operator), bukan rata-rata dari rata-rata polos,
  // supaya operator dengan volume tinggi tidak "kalah suara" dari operator
  // volume rendah saat dihitung total gudang.
  double? get overallAvgProcessingDurationSeconds {
    var weightedSum = 0.0;
    var totalWeight = 0;
    for (final e in _entries) {
      if (e.avgProcessingDurationSeconds != null) {
        weightedSum += e.avgProcessingDurationSeconds! * e.completedCount;
        totalWeight += e.completedCount;
      }
    }
    if (totalWeight == 0) return null;
    return weightedSum / totalWeight;
  }

  ({DateTime start, DateTime end}) _resolveDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_preset) {
      case DateRangePreset.last7Days:
        return (start: today.subtract(const Duration(days: 6)), end: today);
      case DateRangePreset.last30Days:
        return (start: today.subtract(const Duration(days: 29)), end: today);
      case DateRangePreset.thisMonth:
        return (start: DateTime(now.year, now.month, 1), end: today);
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> loadPerformance() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      final range = _resolveDateRange();
      _entries = await _repository.getPerformance(
        warehouseCode: user.warehouseCode,
        startDate: _formatDate(range.start),
        endDate: _formatDate(range.end),
        token: user.token,
      );
      _isLoading = false;
      notifyListeners();
    } catch (_) {
      _hasError = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> changePreset(DateRangePreset newPreset) async {
    _preset = newPreset;
    await loadPerformance();
  }
}