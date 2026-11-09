// lib/repositories/auth_repository.dart (DIUBAH — device jadi DeviceInfo, 3 field payload)
import 'dart:async';
import 'dart:convert';

import '../models/user.dart';
import '../services/api/api_service.dart';
import '../services/database/database_service.dart';
import '../utils/device_identifier.dart';
import 'audit_log_repository.dart';


class AuthRepository {
  final ApiService _apiService = ApiService();
  final AuditLogRepository _auditLogRepository = AuditLogRepository();

  // Endpoint asli stockflow-backend (CONFIRMED PASSED 21 Juli 2026, lihat 02_Feature_Authentication.md).
  // Body sukses (200): { success: true, message: "...", data: { token, nik, userName, role, warehouseCode } }
  // Body gagal (401): { success: false, message: "...", data: null }
  Future<User> login(String nik, String password) async {
    final response = await _apiService.post('/auth/login', {
      'nik': nik,
      'password': password,
      'app': 'MOBILE', // wajib — backend validasi role vs app yang diminta
    });

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 && decoded['success'] == true) {
      final user = User.fromLoginResponse(decoded['data'] as Map<String, dynamic>);

      // 🆕 11 Agustus 2026 — log persisten titik "token diterima dari
      // backend, sebelum SessionService.start() sempat dipanggil dari
      // login_screen.dart". Fire-and-forget (TIDAK di-await), sengaja
      // ditaruh SEBELUM hook Audit Trail di bawah supaya timestamp-nya
      // menangkap urutan asli, bukan ketunda oleh await addLog().
      // Lihat 02_Feature_Authentication.md Known Issues (hipotesis ke-3)
      // & Next Improvement poin 5-6.
      unawaited(DatabaseService().insertAuthLog(
        event: 'LOGIN_TOKEN_RECEIVED',
        nik: user.nik,
        tokenSuffix: _tokenSuffix(user.token),
        detail: 'AuthRepository.login() sukses, about to run audit hook + return user',
      ));

      // 4 Agustus 2026 — hook Audit Trail Mobile (POST /audit-logs), titik
      // pertama dari 3 yang direncanakan (Auth/Submit Transaksi/Print QR).
      // Best-effort, dipanggil PALING TERAKHIR setelah login sudah pasti
      // sukses — kegagalan di sini tidak pernah menggagalkan login.
      //
      // 🆕 (12 Agustus 2026) — DeviceIdentifier.getInfo() (3 komponen:
      // name/ip/id), bukan get() string gabungan lagi.
      await _auditLogRepository.addLog(
        userNik: user.nik,
        userName: user.userName,
        module: 'Auth',
        activity: 'Login berhasil',
        device: await DeviceIdentifier.getInfo(),
        token: user.token,
      );

      return user;
    }

    final message = decoded['message'] as String? ?? 'NIK atau Password tidak valid.';
    throw Exception(message);
  }

  /// 23 Juli 2026 — GAP DITEMUKAN & DIFIX: sebelumnya Logout manual Mobile
  /// cuma clear data lokal (SessionService.stop() + SessionStorageService
  /// .clearUser()), TIDAK PERNAH memberi tahu backend. Akibatnya row sesi
  /// di tabel `sessions` tetap valid=true sampai token JWT expired natural
  /// (8 jam) — kelihatan "masih aktif" di StockFlow Admin (Session
  /// Management) padahal operator sudah logout dari device.
  ///
  /// Endpoint sama persis dengan yang dipakai StockFlow Admin (`POST
  /// /auth/logout`, cabut sesi milik pemanggil sendiri lewat token —
  /// TIDAK butuh body, backend baca token dari Authorization header via
  /// request attribute). Best-effort: kegagalan jaringan TIDAK BOLEH
  /// menghalangi operator logout dari device — silent catch, ProfileViewModel
  /// tetap lanjut ke cleanup lokal apa pun hasilnya.
  Future<void> logout(String token) async {
  // 4 Agustus 2026 — hook Audit Trail DIPANGGIL DULUAN, sebelum invalidate
  // sesi. Urutan ini WAJIB (bukan soal gaya): POST /auth/logout langsung
  // set sesi jadi invalid di backend, dan TokenAuthFilter menolak SEMUA
  // request berikutnya yang pakai token itu — termasuk POST /audit-logs.
  // Log duluan selagi token masih hidup, baru matikan sesinya.
  final nik = _decodeNikFromToken(token);

  // 🆕 11 Agustus 2026 — log persisten, fire-and-forget.
  unawaited(DatabaseService().insertAuthLog(
    event: 'LOGOUT_REQUESTED',
    nik: nik,
    tokenSuffix: _tokenSuffix(token),
  ));

  if (nik != null) {
    // 🆕 (12 Agustus 2026) — DeviceIdentifier.getInfo(), lihat catatan di login().
    await _auditLogRepository.addLog(
      userNik: nik,
      userName: '-',
      module: 'Auth',
      activity: 'Logout manual',
      device: await DeviceIdentifier.getInfo(),
      token: token,
    );
  }

  try {
    await _apiService.post('/auth/logout', {}, token: token);
  } catch (_) {
    // Best-effort — sesi backend akan tetap mati sendiri lewat expiry 8
    // jam natural kalau request ini gagal, atau lewat login ulang NIK
    // yang sama (auto-invalidate sesi lama).
  }
}

  /// Decode claim `sub` (nik) dari JWT tanpa verifikasi signature — cukup
  /// buat kebutuhan display log, BUKAN validasi keamanan (validasi asli
  /// tetap di backend). Return null kalau format token tidak sesuai
  /// dugaan, best-effort dipanggil di atas.
  String? _decodeNikFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final map = jsonDecode(payload) as Map<String, dynamic>;
      return map['sub'] as String?;
    } catch (_) {
      return null;
    }
  }

  String? _tokenSuffix(String? token) {
    if (token == null || token.isEmpty) return null;
    return token.length > 6 ? '...${token.substring(token.length - 6)}' : token;
  }
}