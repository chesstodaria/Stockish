import 'package:flutter/foundation.dart';

/// Status koneksi yang terlihat oleh antarmuka.
///
/// Bukan pemantau jaringan sungguhan: nilainya diturunkan dari hasil
/// pemanggilan data. Pemanggilan yang gagal karena server tidak terjangkau
/// menandai offline, dan pemanggilan yang berhasil mengembalikannya online.
///
/// Dengan data tiruan, status ini hanya berubah kalau kegagalan disimulasikan
/// (`STOCKISI_MOCK_FAIL`). Setelah Supabase dipakai, kegagalan HTTP sungguhan
/// akan menggerakkannya dari satu tempat di lapisan repository.
class ConnectivityStatus extends ChangeNotifier {
  bool _isOnline = true;

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  void reportOnline() {
    if (_isOnline) return;
    _isOnline = true;
    notifyListeners();
  }

  void reportOffline() {
    if (!_isOnline) return;
    _isOnline = false;
    notifyListeners();
  }
}
