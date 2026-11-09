// services/connectivity_service.dart (BARU)
import 'package:flutter/foundation.dart';
import 'poller.dart';
import 'api/api_service.dart';

/// 🆕 (7 Agustus 2026) — Connectivity Banner. App-wide (Sumbu 2), reuse
/// mesin generik Poller yang sama dipakai Titik 1/2/3 (Sumbu 1 tetap
/// terpusat, App-wide vs Scoped cuma beda SIAPA manggil start()/stop(),
/// bukan mekanismenya). Tujuan: indikator murni real-time buat operator
/// SADAR koneksi terputus (biar bisa lapor manual ke tim jaringan,
/// mis. "deket rak X-09 sering putus") — BUKAN sistem telemetry/lokasi,
/// tidak ada data yang dikirim/disimpan ke backend.
class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal() {
    _poller = Poller(interval: const Duration(seconds: 30), onTick: _pingHealth);
  }

  late final Poller _poller;
  final ApiService _apiService = ApiService();

  // Optimistic default (true) — banner baru muncul begitu BENERAN kedeteksi
  // putus, bukan nge-flash "terputus" sekilas pas app baru dibuka.
  bool _isConnected = true;
  bool get isConnected => _isConnected;

  void start() => _poller.start();
  void stop() => _poller.stop();

  /// Fallback aktif — buat kasus operator idle total (tidak ada request
  /// apapun jalan, jadi deteksi pasif di ApiService tidak pernah ke-trigger).
  Future<void> _pingHealth() async {
    try {
      await _apiService.get('/health');
      reportConnected();
    } catch (e) {
      debugPrint('🔍 DEBUG ConnectivityService error: $e'); // 🆕 sementara, hapus nanti
      reportDisconnected();
    }
  }

  /// Dipanggil ApiService begitu ADA request apapun yang sukses (bukan
  /// cuma ping ini) — deteksi pasif, lebih cepat dari nunggu poll berikutnya.
  void reportConnected() {
    if (!_isConnected) {
      _isConnected = true;
      notifyListeners();
    }
  }

  /// Dipanggil ApiService begitu ADA request apapun kena SocketException
  /// (gagal konek beneran — bukan timeout/dedupe-cancel, itu ambigu,
  /// sengaja TIDAK dipakai sebagai sinyal disconnect, biar tidak salah
  /// nunjuk "terputus" padahal cuma kena dedupe request lama).
  void reportDisconnected() {
    if (_isConnected) {
      _isConnected = false;
      notifyListeners();
    }
  }
}