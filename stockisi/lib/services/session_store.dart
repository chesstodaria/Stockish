import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan sesi di perangkat. Yang disimpan hanya NIK operator yang
/// login; profil lengkap selalu diambil ulang dari repository.
///
/// Dipakai `MockAuthRepository`. Implementasi Supabase kemungkinan tidak
/// memerlukannya karena `supabase_flutter` menyimpan sesinya sendiri.
abstract class SessionStore {
  Future<String?> readNik();
  Future<void> writeNik(String nik);
  Future<void> clear();
}

/// Sesi di `flutter_secure_storage`: Keystore di Android, penyimpanan
/// browser terenkripsi di web. Diadaptasi dari
/// `stockish/lib/services/session/session_storage_service.dart`.
class SecureSessionStore implements SessionStore {
  static const _key = 'stockisi_session_nik';
  final FlutterSecureStorage _storage;

  SecureSessionStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> readNik() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      // Penyimpanan rusak atau tidak bisa dibaca: anggap belum login.
      return null;
    }
  }

  @override
  Future<void> writeNik(String nik) => _storage.write(key: _key, value: nik);

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // Gagal menghapus tidak boleh menghalangi logout.
    }
  }
}

/// Sesi di memori, untuk test.
class InMemorySessionStore implements SessionStore {
  String? _nik;

  @override
  Future<String?> readNik() async => _nik;

  @override
  Future<void> writeNik(String nik) async => _nik = nik;

  @override
  Future<void> clear() async => _nik = null;
}
