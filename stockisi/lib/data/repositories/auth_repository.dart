import '../../models/operator_profile.dart';

/// Autentikasi operator dan sesi di perangkat.
///
/// Semua repository lain bekerja atas nama operator yang sedang login dan
/// otomatis dibatasi ke gudangnya. Layar tidak pernah mengirim kode gudang.
abstract class AuthRepository {
  /// Login dengan NIK dan kata sandi. Kalau berhasil, sesi tersimpan di
  /// perangkat dan profil operator dikembalikan.
  ///
  /// Melempar `AuthException`:
  /// - `invalidCredentials` untuk NIK tidak terdaftar maupun kata sandi
  ///   salah (satu pesan yang sama, supaya tidak membocorkan NIK).
  /// - `inactiveAccount` untuk akun nonaktif.
  ///
  /// Melempar `DataUnavailableException` kalau server tidak bisa dihubungi.
  Future<OperatorProfile> login(String nik, String password);

  /// Profil operator dari sesi yang tersimpan, atau null kalau belum ada
  /// sesi. Dipakai Splash untuk memilih halaman utama atau login.
  Future<OperatorProfile?> restoreSession();

  /// Menghapus sesi di perangkat. Tidak pernah gagal dari sisi layar.
  Future<void> logout();
}
