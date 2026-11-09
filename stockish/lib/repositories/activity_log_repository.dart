import 'dart:convert';
import '../models/activity_log.dart';
import '../models/performance_entry.dart';
import '../services/api/api_service.dart';

class ActivityLogRepository {
  final ApiService _apiService = ApiService();

  Future<void> addLog(ActivityLog log, String token) async {
    try {
      await _apiService.post('/activity-log', log.toJson(), token: token);
    } catch (e) {
      // Best-effort — kegagalan pencatatan log TIDAK boleh menggagalkan
      // submit yang sudah sukses.
    }
  }

  Future<List<ActivityLog>> getLogsByNik(String nik, String token) async {
    final response = await _apiService.get('/activity-log?nik=$nik', token: token);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (!(response.statusCode == 200 && decoded['success'] == true)) {
      throw Exception(decoded['message'] as String? ?? 'Gagal mengambil riwayat aktivitas.');
    }

    final data = decoded['data'] as List<dynamic>;
    return data.map((e) => ActivityLog.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ActivityLog>> getLogsByWarehouse(String warehouseCode, String token) async {
    final response =
        await _apiService.get('/activity-log?warehouseCode=$warehouseCode', token: token);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (!(response.statusCode == 200 && decoded['success'] == true)) {
      throw Exception(decoded['message'] as String? ?? 'Gagal mengambil riwayat aktivitas.');
    }

    final data = decoded['data'] as List<dynamic>;
    return data.map((e) => ActivityLog.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// BARU (29 Juli 2026) — fitur Performa. startDate/endDate format
  /// "yyyy-MM-dd" (dipakai backend LocalDate.parse()).
  Future<List<PerformanceEntry>> getPerformance({
    required String warehouseCode,
    required String startDate,
    required String endDate,
    required String token,
  }) async {
    final response = await _apiService.get(
      '/activity-log/performance?warehouseCode=$warehouseCode&startDate=$startDate&endDate=$endDate',
      token: token,
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (!(response.statusCode == 200 && decoded['success'] == true)) {
      throw Exception(decoded['message'] as String? ?? 'Gagal mengambil data performa.');
    }

    final data = decoded['data'] as List<dynamic>;
    return data.map((e) => PerformanceEntry.fromJson(e as Map<String, dynamic>)).toList();
  }
}