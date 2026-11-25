import '../../models/document_claim.dart';

/// Klaim sementara atas dokumen referensi.
///
/// Kunci mencegah dua operator mengerjakan dokumen yang sama. Ia bukan
/// pengganti validasi `version` saat submit: dokumen tetap diperiksa ulang
/// di server, karena klaim bisa kedaluwarsa di tengah pekerjaan.
abstract class DocumentClaimRepository {
  /// Klaim yang sedang berlaku untuk satu dokumen, atau null kalau bebas.
  ///
  /// Klaim yang sudah kedaluwarsa dianggap tidak ada.
  Future<DocumentClaim?> getClaim(String documentNumber);

  /// Mengambil klaim untuk operator yang sedang login.
  ///
  /// Berhasil kalau dokumen belum diklaim, sudah diklaim oleh diri sendiri,
  /// atau klaim lama sudah kedaluwarsa. Gagal kalau masih dipegang operator
  /// lain.
  Future<ClaimOutcome> claim(String documentNumber);

  /// Melepas klaim. Tidak gagal kalau klaim memang tidak ada atau bukan
  /// milik pemanggil.
  Future<void> release(String documentNumber);

  /// Semua klaim aktif, dipakai daftar dokumen untuk menandai kartu yang
  /// sedang dikerjakan operator lain.
  Future<List<DocumentClaim>> activeClaims();
}
