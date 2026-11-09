// lib/services/app_settings_cache.dart (BARU) — 18 Agustus 2026
import '../repositories/app_settings_repository.dart';

/// Cache in-memory Setting Sesi Mobile (Lock Timer/Polling/Idle-timeout),
/// di-load SEKALI setelah login manual (login_screen.dart) atau restore
/// sesi (splash_screen.dart), sebelum SessionService().start() dipanggil
/// (supaya pollInterval yang dipakai Timer.periodic() sudah nilai terbaru).
///
/// Field null = belum pernah berhasil di-load (gagal network / fresh
/// install) — LockTimerService/SessionService masing-masing fallback ke
/// default sendiri kalau null, BUKAN cache ini yang nyimpen default.
///
/// idleTimeoutMinutes DISIMPAN di sini tapi BELUM DIPAKAI ENFORCEMENT
/// apa pun (menyusul — desain terpisah, lihat 05_Decision_Log.md 18
/// Agustus 2026 & entri "Setting Lamanya Sesi Mobile" 18 Agustus).
class AppSettingsCache {
  AppSettingsCache._internal();
  static final AppSettingsCache _instance = AppSettingsCache._internal();
  factory AppSettingsCache() => _instance;

  final AppSettingsRepository _repository = AppSettingsRepository();

  int? lockTimerMinutes;
  int? pollIntervalMinutes;
  int? idleTimeoutMinutes;

  Future<void> loadFromServer(String token) async {
    final settings = await _repository.getMobileSessionSettings(token);
    if (settings == null) return; // gagal — field tetap null, konsumen fallback sendiri

    lockTimerMinutes = settings['lockTimerMinutes'];
    pollIntervalMinutes = settings['pollIntervalMinutes'];
    idleTimeoutMinutes = settings['idleTimeoutMinutes'];
  }
}