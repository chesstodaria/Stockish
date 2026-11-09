// lib/repositories/erp_push_repository.dart (REPLACE FULL — defensif terhadap response gagal/bukan JSON, 24 Agustus 2026)
import 'dart:convert';

import '../models/erp_push_status.dart';
import '../models/user.dart';
import '../services/api/api_service.dart';
import '../utils/device_identifier.dart';

/// Push Monitoring, sisi Mobile — reuse pola `getStatusForRequester()`
/// Print Job Queue. `nik` operator dibaca backend dari token
/// (`TokenAuthFilter`), BUKAN query param — beda dari `PrintJobRepository`.
///
/// 🆕 (24 Agustus 2026) — getStatus() dibungkus try/catch: response gagal
/// (network error, 401, body bukan JSON valid, endpoint belum konek) TIDAK
/// BOLEH throw ke pemanggil (ViewModel/Tile badge Dashboard) — cukup
/// balikin list kosong, konsisten pola PrintJobRepository.getStatus().
/// Sebelumnya versi ini throw mentah dari jsonDecode()/cast, ditemukan jadi
/// penyebab UI Dashboard rusak (tile kosong) saat fetch badge gagal.
class ErpPushRepository {
  final ApiService _apiService = ApiService();

  Future<List<ErpPushStatus>> getStatus(User user) async {
    try {
      final response = await _apiService.get(
        '/erp-push/status',
        token: user.token,
      );

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && decoded['success'] == true) {
        final data = decoded['data'] as List<dynamic>;
        return data
            .map((e) => ErpPushStatus.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      // Network error, timeout, body bukan JSON, field tak terduga, dsb —
      // badge/Screen cukup tampil kosong, bukan crash.
      return [];
    }
  }

  /// Tombol "Kirim Ulang" — hanya boleh dipanggil untuk baris
  /// NEEDS_MANUAL_RETRY (Kondisi 3). Backend yang re-validasi status
  /// (jangan percaya UI state semata). Ini TETAP boleh throw — Screen yang
  /// panggil (_handleRetry) sudah punya try/catch sendiri buat tampilkan
  /// SnackBar error, beda konteks dari getStatus() yang dipanggil silent
  /// di background (badge).
    /// 🆕 (24 Agustus 2026, sesi lanjutan lagi) — kirim device info (Gap #7),
  /// sebelumnya body selalu {} kosong. DeviceIdentifier.getInfo() async
  /// (baca secure storage), await sebelum build body.
  Future<void> retry(User user, int pushStatusId) async {
    final device = await DeviceIdentifier.getInfo();
    final response = await _apiService.post(
      '/erp-push/$pushStatusId/retry',
      {
        'device': device.name,
        'deviceIp': device.ip,
        'deviceId': device.id,
      },
      token: user.token,
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (!(response.statusCode == 200 && decoded['success'] == true)) {
      final message = decoded['message'] as String? ?? 'Gagal mengirim ulang.';
      throw Exception(message);
    }
  }
}