// lib/services/session/session_storage_service.dart (REPLACE FULL — Remember Login DIMATIKAN, 18 Agustus 2026)
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 🔧 (18 Agustus 2026) — Remember Login DIMATIKAN TOTAL (Restrukturisasi
/// Auth Tim IT, 05_Decision_Log.md 18 Agustus 2026). `saveUser()`/`getUser()`
/// DIHAPUS — tidak pernah dipanggil lagi dari mana pun (LoginScreen tidak
/// lagi simpan sesi, SplashScreen tidak lagi restore sesi).
///
/// `clearUser()` SENGAJA DIPERTAHANKAN — bukan dead code, dipakai
/// SplashScreen untuk PURGE SEKALI TANPA SYARAT tiap app dibuka, membersihkan
/// data lama yang sudah TERLANJUR tersimpan di device operator yang pernah
/// pakai Remember Login SEBELUM update ini terpasang (NIK/nama/token lama,
/// orphaned — tidak akan pernah terbaca/terhapus lagi kalau method ini juga
/// ikut dihapus). Aman dipanggil berulang kali/pada storage yang sudah
/// kosong — no-op, bukan error.
class SessionStorageService {
  static final SessionStorageService _instance =
      SessionStorageService._internal();
  factory SessionStorageService() => _instance;
  SessionStorageService._internal();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _userKey = 'remembered_user';

  Future<void> clearUser() async {
    await _storage.delete(key: _userKey);
  }
}