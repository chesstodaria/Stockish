// lib/repositories/audit_log_repository.dart (DIUBAH — device jadi DeviceInfo, 3 field payload)
import 'dart:async';
import 'dart:convert';

import '../services/api/api_service.dart';
import '../services/database/database_service.dart';
import '../utils/device_identifier.dart';

/// Repository Audit Trail sisi Mobile — kirim ke `POST /audit-logs`.
/// Best-effort: kegagalan pencatatan log TIDAK BOLEH menggagalkan aksi
/// utama yang sudah sukses terjadi sebelum method ini dipanggil.
///
/// 🆕 (12 Agustus 2026) — parameter `device` sekarang `DeviceInfo` (3
/// komponen: name/ip/id), bukan String gabungan lagi — payload kirim 3
/// field terpisah (`device`/`deviceIp`/`deviceId`), dipetakan ke 3 kolom
/// tabel Audit Trail Admin.
///
/// Offline queue + opportunistic flush (12 Agustus 2026, desain 6 Agustus)
/// tetap sama — payload disimpan mentah sebagai JSON string, jadi otomatis
/// ikut membawa 3 field device baru tanpa perlu ubah logic queue/flush.
class AuditLogRepository {
  final ApiService _apiService = ApiService();

  static bool _hookRegistered = false;
  static bool _isFlushing = false;

  AuditLogRepository() {
    if (!_hookRegistered) {
      _hookRegistered = true;
      ApiService.registerOnRequestSuccess(() {
        unawaited(_flushQueue());
      });
    }
  }

  Future<void> addLog({
    required String userNik,
    required String userName,
    required String module,
    required String activity,
    required DeviceInfo device,
    required String token,
    String category = 'OTHER',
    List<String>? relatedItemCodes,
    String? reason,
  }) async {
    final payload = {
      'userNik': userNik,
      'userName': userName,
      'module': module,
      'activity': activity,
      'device': device.name,
      'deviceIp': device.ip,
      'deviceId': device.id,
      'source': 'MOBILE',
      'category': category,
      if (relatedItemCodes != null) 'relatedItemCodes': relatedItemCodes,
      if (reason != null) 'reason': reason,
    };

    try {
      await _apiService.post('/audit-logs', payload, token: token);
    } catch (e) {
      try {
        await DatabaseService().insertQueuedAuditLog(
          payload: jsonEncode(payload),
          token: token,
        );
      } catch (_) {
        // Best-effort total — lihat penjelasan di atas.
      }
    }
  }

  static Future<void> _flushQueue() async {
    if (_isFlushing) return;
    _isFlushing = true;

    try {
      final queued = await DatabaseService().getQueuedAuditLogs();
      if (queued.isEmpty) return;

      final apiService = ApiService();

      for (final row in queued) {
        try {
          final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
          final token = row['token'] as String;
          final id = row['id'] as int;

          final response = await apiService.post('/audit-logs', payload, token: token);

          if (response.statusCode >= 200 && response.statusCode < 300) {
            await DatabaseService().deleteQueuedAuditLog(id);
          }
        } catch (_) {
          // 1 baris gagal tidak boleh menghentikan proses baris lain.
        }
      }
    } finally {
      _isFlushing = false;
    }
  }
}