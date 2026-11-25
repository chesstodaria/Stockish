import '../../models/audit_event.dart';

/// Jejak aktivitas di gudang operator, terbaru dulu.
///
/// Hanya baca. Penulisan terjadi di sisi basis data lewat trigger dan RPC,
/// sehingga tidak ada jalur bagi aplikasi untuk mengubah atau menghapus
/// jejak yang sudah tercatat.
abstract class AuditRepository {
  /// Aktivitas gudang operator yang sedang login.
  ///
  /// Melempar `DataUnavailableException` kalau gagal memuat.
  Future<List<AuditEvent>> recent({int limit = 100});
}
