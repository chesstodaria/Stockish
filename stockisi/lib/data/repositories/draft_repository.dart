import '../../models/draft.dart';

/// Draf transaksi milik operator yang sedang login.
///
/// Tempat penyimpanannya (perangkat atau Supabase) belum diputuskan
/// kelompok. Janji ke layar sama untuk keduanya.
abstract class DraftRepository {
  /// Draf untuk satu dokumen, atau null kalau tidak ada.
  ///
  /// Draf dikembalikan apa adanya walaupun dokumennya sudah berubah. Layar
  /// yang membandingkan `basedOnVersion` dengan versi dokumen terbaru.
  Future<Draft?> getDraft(String documentNumber);

  /// Nomor dokumen yang punya draf. Dipakai untuk penanda "Ada draf" di
  /// daftar dokumen dan peringatan sebelum logout.
  Future<Set<String>> getDocumentNumbersWithDraft();

  /// Menyimpan atau mengganti draf satu dokumen.
  Future<void> saveDraft(Draft draft);

  /// Membuang draf satu dokumen. Tidak gagal kalau draf tidak ada.
  Future<void> deleteDraft(String documentNumber);
}
