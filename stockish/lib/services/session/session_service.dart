// lib/services/session/session_service.dart (REPLACE FULL — 20 Agustus 2026, fix
// dokumen tidak ter-release saat force-logout/idle-timeout. Ditemukan saat testing
// idle-timeout Skenario B: dokumen yang lagi di-lock operator TIDAK ikut lepas saat
// sesinya dipaksa berakhir (idle-timeout), nyangkut di StockFlow Admin > Force Unlock
// sampai di-unlock manual. Root cause: _triggerForceLogout() cuma invalidate sesi
// lokal, tidak pernah tahu/peduli dokumen mana yang lagi di-lock. Fix: reuse
// LockTimerService().activeReferenceNumber (sudah ada, dipakai badge countdown) —
// kalau ada dokumen aktif, unlock ke backend SEBELUM stop(). Berlaku untuk SEMUA
// jalur force-logout (idle-timeout, Admin force-logout via poll, interceptor 401
// global), bukan cuma idle-timeout — karena semuanya lewat _triggerForceLogout() ini.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../repositories/reference_document_repository.dart';
import '../api/api_service.dart';
import '../database/database_service.dart';
import '../app_settings_cache.dart';
import '../lock_timer_service.dart';

enum SessionCheckStatus {
  valid,
  invalid,
  unknown,
}

class SessionService extends ChangeNotifier with WidgetsBindingObserver {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  final ApiService _apiService = ApiService();

  // 🆕 (20 Agustus 2026) — dipakai _triggerForceLogout() buat unlock
  // dokumen aktif. Instance biasa (bukan static), konsisten pola
  // ReferenceDocumentRepository lain (mis. dipakai TransactionDetailScreen).
  final ReferenceDocumentRepository _docRepository = ReferenceDocumentRepository();

  // 🔧 (18 Agustus 2026) — GANTI dari `static const` jadi GETTER — baca
  // AppSettingsCache dulu (Setting Sesi Mobile dari Admin), fallback ke
  // default 1 menit kalau cache belum ke-load/gagal. Dipanggil di start()
  // (lihat di bawah) — AppSettingsCache().loadFromServer() WAJIB sudah
  // selesai sebelum start() dipanggil (lihat login_screen.dart/
  // splash_screen.dart), atau nilai fallback yang dipakai.
  static Duration get pollInterval {
    final minutes = AppSettingsCache().pollIntervalMinutes;
    return minutes != null ? Duration(minutes: minutes) : const Duration(minutes: 1);
  }

  // 🆕 (19 Agustus 2026) — Idle-timeout sesi UI, konsep baru dari
  // Setting Sesi Mobile (nilai sudah tersimpan di AppSettingsCache sejak
  // 18 Agustus, enforcement-nya baru ditambahkan sekarang). Pola getter
  // sama persis pollInterval di atas.
  static Duration get idleTimeout {
    final minutes = AppSettingsCache().idleTimeoutMinutes;
    return minutes != null ? Duration(minutes: minutes) : const Duration(minutes: 15);
  }

  Timer? _pollTimer;
  Timer? _idleTimer; // 🆕
  User? _currentUser;
  bool _isActive = false;

  bool get isActive => _isActive;

  /// Pesan ASLI dari backend saat sesi ternyata invalid (dibaca dari
  /// `TokenAuthFilter.buildInvalidSessionMessage()`). Null kalau belum
  /// pernah ada kejadian invalid, atau kalau invalid-nya dari 401 tanpa
  /// body JSON valid (fallback ke teks default di main.dart).
  String? lastInvalidMessage;

  void start(User user) {
    _currentUser = user;
    _isActive = true;
    WidgetsBinding.instance.addObserver(this);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) => _checkSession());
    _resetIdleTimer(); // 🆕 — mulai hitung idle sejak sesi dimulai
    debugPrint('🔍[SESSION] start() nik=${user.nik}, interval=$pollInterval, idleTimeout=$idleTimeout');

    // 🆕 11 Agustus 2026 — log persisten (fire-and-forget, TIDAK di-await
    // supaya tidak menambah window race), buat investigasi "kick sesi
    // misterius" hipotesis ke-3 (02_Feature_Authentication.md).
    unawaited(_logAuth(
      'SESSION_START',
      nik: user.nik,
      token: user.token,
      detail: 'pollInterval=$pollInterval; idleTimeout=$idleTimeout',
    ));
    // Housekeeping ringan — purge log lama tiap kali sesi baru dimulai
    // (login/restore), bukan scheduler terpisah.
    unawaited(DatabaseService().purgeOldAuthLogs());
  }

  void stop() {
    debugPrint('🔍[SESSION] stop()');
    _pollTimer?.cancel();
    _pollTimer = null;
    _idleTimer?.cancel(); // 🆕
    _idleTimer = null; // 🆕
    _isActive = false;
    _currentUser = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  // 🆕 (19 Agustus 2026) — dipanggil dari Listener global di main.dart
  // tiap ada interaksi apa pun (tap/scroll/dsb) di seluruh app. Reset
  // countdown idle-timeout dari awal. No-op kalau sesi belum aktif —
  // aman dipanggil dari Login/Splash Screen sekalipun sebelum start().
  void recordActivity() {
    if (!_isActive) return;
    _resetIdleTimer();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, _handleIdleTimeout);
  }

  // 🆕 (19 Agustus 2026) — reuse alur force-logout yang sudah ada
  // (_triggerForceLogout()), cuma bedanya pesan yang ditampilkan ke
  // operator (bukan "dicabut oleh Admin", tapi "tidak ada aktivitas").
  void _handleIdleTimeout() {
    if (!_isActive) return;
    debugPrint('🔍[SESSION] IDLE TIMEOUT tercapai (${idleTimeout.inMinutes} menit tanpa aktivitas)');
    lastInvalidMessage = 'Sesi berakhir karena tidak ada aktivitas. Silakan login kembali.';
    unawaited(_logAuth(
      'IDLE_TIMEOUT_TRIGGERED',
      nik: _currentUser?.nik,
      token: _currentUser?.token,
      detail: 'idleTimeout=$idleTimeout',
    ));
    _triggerForceLogout();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isActive) return;
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔍[SESSION] app resumed, cek sesi ulang');
      _checkSession();
    }
  }

  Future<void> _checkSession() async {
    if (!_isActive || _currentUser == null) return;
    unawaited(_logAuth(
      'POLL_TICK',
      nik: _currentUser?.nik,
      token: _currentUser?.token,
    ));
    final status = await checkSessionOnce(_currentUser!.token, context: 'poll');
    if (status == SessionCheckStatus.invalid) _triggerForceLogout();
  }

  Future<SessionCheckStatus> checkSessionOnce(
    String token, {
    String context = 'unknown',
  }) async {
    try {
      final response =
          await _apiService.get('/auth/session-check', token: token);

      if (response.statusCode == 401) {
        lastInvalidMessage = _extractMessage(response.body);
        debugPrint('🔍[SESSION] checkOnce 401 — sesi dicabut/expired, invalid. Pesan: $lastInvalidMessage');
        unawaited(_logAuth(
          'SESSION_CHECK_401',
          nik: _currentUser?.nik,
          token: token,
          detail: 'context=$context; message=$lastInvalidMessage',
        ));
        return SessionCheckStatus.invalid;
      }

      if (response.statusCode != 200) {
        debugPrint('🔍[SESSION] checkOnce status ${response.statusCode} (bukan 200/401) — unknown');
        unawaited(_logAuth(
          'SESSION_CHECK_UNKNOWN_STATUS',
          nik: _currentUser?.nik,
          token: token,
          detail: 'context=$context; statusCode=${response.statusCode}',
        ));
        return SessionCheckStatus.unknown;
      }

      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
      final valid = data is Map<String, dynamic> ? data['valid'] == true : true;
      debugPrint('🔍[SESSION] checkOnce result valid=$valid');
      if (!valid) lastInvalidMessage = _extractMessage(response.body);
      unawaited(_logAuth(
        valid ? 'SESSION_CHECK_VALID' : 'SESSION_CHECK_INVALID',
        nik: _currentUser?.nik,
        token: token,
        detail: 'context=$context',
      ));
      return valid ? SessionCheckStatus.valid : SessionCheckStatus.invalid;
    } catch (e) {
      debugPrint('🔍[SESSION] checkOnce gagal (network/server), unknown: $e');
      unawaited(_logAuth(
        'SESSION_CHECK_EXCEPTION',
        nik: _currentUser?.nik,
        token: token,
        detail: 'context=$context; error=$e',
      ));
      return SessionCheckStatus.unknown;
    }
  }

  String? _extractMessage(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      return decoded is Map<String, dynamic> ? decoded['message'] as String? : null;
    } catch (_) {
      return null;
    }
  }

  Future<SessionCheckStatus> checkNow() async {
    if (!_isActive || _currentUser == null) return SessionCheckStatus.unknown;
    final status = await checkSessionOnce(_currentUser!.token, context: 'manual');
    if (status == SessionCheckStatus.invalid) _triggerForceLogout();
    return status;
  }

  /// 🆕 (6 Agustus 2026) — dipanggil `ApiService` (Interceptor global 401)
  /// saat request APAPUN yang pakai token menerima 401 dari server, bukan
  /// cuma dari polling `_checkSession()`/`checkSessionOnce()` sendiri.
  /// Reuse alur trigger yang sama persis — guard `_isActive` di
  /// `_triggerForceLogout()` otomatis cegah double-trigger kalau
  /// bertepatan dengan polling.
  void reportUnauthorized(String responseBody) {
    if (!_isActive) return;
    final msg = _extractMessage(responseBody);
    if (msg != null) lastInvalidMessage = msg;
    debugPrint('🔍[SESSION] reportUnauthorized() dari interceptor global 401. Pesan: $lastInvalidMessage');
    unawaited(_logAuth(
      'INTERCEPTOR_401_REPORTED',
      nik: _currentUser?.nik,
      token: _currentUser?.token,
      detail: lastInvalidMessage,
    ));
    _triggerForceLogout();
  }

  void _triggerForceLogout() {
    if (!_isActive) return;
    debugPrint('🔍[SESSION] FORCE LOGOUT dipicu. Pesan: $lastInvalidMessage');
    // Capture SEBELUM stop() — stop() clear _currentUser jadi null.
    final nikForLog = _currentUser?.nik;
    final tokenForLog = _currentUser?.token;

    // 🆕 (20 Agustus 2026) — FIX gap dokumen tidak ter-release. Kalau
    // operator lagi pegang lock dokumen (LockTimerService aktif) saat
    // force-logout kejadian (idle-timeout, dicabut Admin, atau 401 apa
    // pun), unlock ke backend DULU sebelum sesi diinvalidate — supaya
    // dokumen langsung bisa diambil device lain, tidak nyangkut sampai
    // Admin manual Force Unlock. Fire-and-forget (tidak di-await) —
    // navigasi ke Login tidak boleh nunggu network round-trip ini,
    // konsisten pola _logAuth() lain di file ini. Best-effort: kalau gagal
    // (network mati bareng), dokumen tetap nyangkut seperti sebelumnya —
    // tidak lebih buruk dari kondisi sebelum fix ini.
    final lockedRef = LockTimerService().activeReferenceNumber;
    if (lockedRef != null && tokenForLog != null) {
      debugPrint('🔍[SESSION] FORCE LOGOUT: dokumen $lockedRef masih terkunci, unlock dulu...');
      unawaited(_docRepository.unlockDocument(lockedRef, tokenForLog).catchError((e) {
        debugPrint('🔍[SESSION] FORCE LOGOUT: unlock $lockedRef gagal (diabaikan, best-effort): $e');
      }));
      LockTimerService().cancel();
    }

    unawaited(_logAuth(
      'FORCE_LOGOUT_TRIGGERED',
      nik: nikForLog,
      token: tokenForLog,
      detail: lastInvalidMessage,
    ));
    stop();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // 🆕 11 Agustus 2026 — Auth Debug Log helper (fire-and-forget wrapper)
  // ---------------------------------------------------------------------

  Future<void> _logAuth(
    String event, {
    String? nik,
    String? token,
    String? detail,
  }) async {
    try {
      await DatabaseService().insertAuthLog(
        event: event,
        nik: nik,
        tokenSuffix: _tokenSuffix(token),
        detail: detail,
      );
    } catch (_) {
      // Never-throw — sudah di-handle juga di dalam insertAuthLog, ini
      // lapisan pengaman kedua.
    }
  }

  String? _tokenSuffix(String? token) {
    if (token == null || token.isEmpty) return null;
    return token.length > 6 ? '...${token.substring(token.length - 6)}' : token;
  }
}