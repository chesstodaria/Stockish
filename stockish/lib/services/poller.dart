// services/poller.dart (BARU)
import 'dart:async';
import 'package:flutter/foundation.dart';

/// 🆕 (7 Agustus 2026) — Targeted Auto-Refresh, mesin generik "Scoped
/// poller". Dipakai masing-masing ViewModel yang butuh, instance sendiri-
/// sendiri — BUKAN nempel ke SessionService (App-wide, beda kelas
/// kebutuhan). Guard `_isTicking` cegah tick numpuk kalau network lambat.
class Poller {
  final Duration interval;
  final Future<void> Function() onTick;

  Timer? _timer;
  bool _isTicking = false;

  Poller({required this.interval, required this.onTick});

  bool get isActive => _timer != null;

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) async {
      if (_isTicking) {
        debugPrint('🔍[POLLER] tick dilewati, tick sebelumnya belum selesai');
        return;
      }
      _isTicking = true;
      try {
        await onTick();
      } catch (e) {
        debugPrint('🔍[POLLER] tick gagal, diabaikan: $e');
      } finally {
        _isTicking = false;
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}