// lib/repositories/app_settings_repository.dart (BARU) — 18 Agustus 2026
import 'dart:convert';
import '../services/api/api_service.dart';

class AppSettingsRepository {
  final ApiService _apiService = ApiService();

  /// Ambil Setting Sesi Mobile dari server. Best-effort — kegagalan apa pun
  /// (network/belum ada config/parse error) balikin null, BUKAN throw.
  /// Caller (AppSettingsCache) fallback ke default lokal kalau null.
  Future<Map<String, int>?> getMobileSessionSettings(String token) async {
    try {
      final response = await _apiService.get('/settings/mobile-session', token: token);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>?;
      if (data == null) return null;

      return {
        'lockTimerMinutes': data['lockTimerMinutes'] as int,
        'pollIntervalMinutes': data['pollIntervalMinutes'] as int,
        'idleTimeoutMinutes': data['idleTimeoutMinutes'] as int,
      };
    } catch (_) {
      return null;
    }
  }
}