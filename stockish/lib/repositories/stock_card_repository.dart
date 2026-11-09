import 'dart:convert';
import '../models/stock_item.dart';
import '../models/stock_movement.dart';
import '../services/api/api_service.dart';

/// 24 Juli 2026 — SELESAI disambungkan ke stockflow-backend, menggantikan
/// mock in-memory. searchItems() reuse endpoint GET /items yang sama
/// dipakai fitur Investigation (StockFlow Admin) — endpoint ini belum
/// punya konsep search di server, jadi filter query tetap dilakukan lokal
/// di ViewModel (pola sama sebelumnya), cuma sumber datanya sekarang real.
class StockCardRepository {
  final ApiService _apiService = ApiService();

  /// 🔧 (12 Agustus 2026) — filter warehouseCode SEKARANG genuinely
  /// dilakukan (dibandingkan ke data server), bukan lagi kosmetik.
  /// SEBELUMNYA: parameter warehouseCode cuma dilewatkan ke
  /// StockItem.fromJson buat pengisian tampilan — server belum punya
  /// data per-warehouse untuk item saat itu (24 Juli 2026), jadi filter
  /// ini dulu tidak mungkin genuinely jalan. Sekarang backend ItemResponse
  /// sudah kirim warehouseCode asli (Item#3, 10 Agustus 2026) — filter
  /// dipindah ke sini (titik paling awal data masuk), bukan di ViewModel,
  /// supaya konsisten dengan prinsip "validasi/filter dekat sumber data".
  Future<List<StockItem>> searchItems(String query, {required String warehouseCode, required String token}) async {
    final response = await _apiService.get('/items', token: token);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (!(response.statusCode == 200 && decoded['success'] == true)) {
      throw Exception(decoded['message'] as String? ?? 'Gagal mengambil daftar barang.');
    }

    final data = decoded['data'] as List<dynamic>;
    return data
        .map((e) => StockItem.fromJson(e as Map<String, dynamic>))
        .where((item) => item.warehouseCode == warehouseCode)
        .toList();
  }

  Future<List<StockMovement>> getMovements(String itemCode, {required String token}) async {
    final response = await _apiService.get('/stock-card?itemCode=$itemCode', token: token);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (!(response.statusCode == 200 && decoded['success'] == true)) {
      throw Exception(decoded['message'] as String? ?? 'Gagal mengambil riwayat pergerakan.');
    }

    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) return []; // barang tidak ditemukan di server

    final historyJson = data['history'] as List<dynamic>? ?? [];
    final movements = historyJson.map((e) => StockMovement.fromJson(e as Map<String, dynamic>)).toList();
    movements.sort((a, b) => b.date.compareTo(a.date)); // sudah di-sort server, sort lagi di client = jaga-jaga
    return movements;
  }
}