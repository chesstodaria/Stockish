// lib/repositories/print_job_repository.dart (baru)
import 'dart:convert';

import '../models/print_job.dart';
import '../models/user.dart';
import '../services/api/api_service.dart';

/// 🆕 (11 Agustus 2026) — Print Job Queue, sisi Mobile. Opsi TAMBAHAN
/// "Print via Jaringan" di samping dialog print Android biasa (Printing
/// .layoutPdf() TETAP ada, tidak digantikan) — kirim PDF yang sudah
/// digenerate ke backend, StockFlow Admin (mode Print Listener) yang
/// mencetak ke printer lokal.
class PrintJobRepository {
  final ApiService _apiService = ApiService();

  Future<PrintJob> submit({
    required User user,
    required List<int> pdfBytes,
    required int itemCount,
  }) async {
    final response = await _apiService.post(
      '/print-jobs',
      {
        'requestedByNik': user.nik,
        'requestedByName': user.userName,
        'warehouseCode': user.warehouseCode,
        'pdfBase64': base64Encode(pdfBytes),
        'itemCount': itemCount,
      },
      token: user.token,
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && decoded['success'] == true) {
      return PrintJob.fromJson(decoded['data'] as Map<String, dynamic>);
    }

    final message = decoded['message'] as String? ?? 'Gagal mengirim print job.';
    throw Exception(message);
  }

  /// Status job milik NIK ini, terbaru duluan — dipakai buat nampilin
  /// PENDING/PRINTED/FAILED/EXPIRED tanpa polling otomatis (operator cek
  /// manual lewat tombol refresh).
  Future<List<PrintJob>> getStatus(User user) async {
    final response = await _apiService.get(
      '/print-jobs/status?requestedByNik=${user.nik}',
      token: user.token,
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && decoded['success'] == true) {
      final data = decoded['data'] as List<dynamic>;
      return data.map((e) => PrintJob.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }
}