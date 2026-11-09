/// Hasil parsing 1 baris response GET /activity-log/performance — 1 baris
/// per operator, di-scope Warehouse+rentang tanggal (lihat
/// ActivityLogRepository.getPerformance()). avgProcessingDurationSeconds
/// nullable — null kalau operator itu belum pernah punya entry dengan
/// processingDurationSeconds terisi (mis. entry lama sebelum kolom ini ada).
class PerformanceEntry {
  final String nik;
  final String name;
  final int completedCount;
  final double? avgProcessingDurationSeconds;

  PerformanceEntry({
    required this.nik,
    required this.name,
    required this.completedCount,
    this.avgProcessingDurationSeconds,
  });

  factory PerformanceEntry.fromJson(Map<String, dynamic> json) {
    return PerformanceEntry(
      nik: json['nik'] as String,
      name: json['name'] as String? ?? '',
      completedCount: json['completedCount'] as int,
      avgProcessingDurationSeconds:
          (json['avgProcessingDurationSeconds'] as num?)?.toDouble(),
    );
  }
}