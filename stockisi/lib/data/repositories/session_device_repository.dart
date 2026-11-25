/// Pendaftaran sesi perangkat.
///
/// Satu NIK hanya boleh aktif di satu perangkat. Tujuannya mencegah dua
/// operator memakai akun yang sama pada dua perangkat sekaligus, yang akan
/// membuat jejak audit dan klaim dokumen tidak bisa dipercaya.
abstract class SessionDeviceRepository {
  /// Perangkat yang sedang memegang sesi untuk [nik], atau null.
  Future<String?> activeDevice(String nik);

  /// Mendaftarkan [deviceId] sebagai pemegang sesi [nik].
  ///
  /// Mengembalikan `true` kalau berhasil. Mengembalikan `false` kalau sesi
  /// masih dipegang perangkat lain dan [force] tidak diminta; dalam hal itu
  /// [activeDevice] memberi tahu perangkat mana yang memegangnya.
  Future<bool> register(String nik, String deviceId, {bool force = false});

  /// Melepas sesi. Tidak gagal kalau sesi memang sudah tidak ada.
  Future<void> unregister(String nik, String deviceId);
}
