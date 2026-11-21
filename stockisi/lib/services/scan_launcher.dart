import 'package:flutter/widgets.dart';

enum CameraProblem {
  /// Izin kamera ditolak.
  permissionDenied,

  /// Perangkat atau browser tidak punya kamera yang bisa dipakai.
  unavailable,
}

/// Hasil membuka scanner. Null kalau operator menutup scanner sendiri.
sealed class ScanOutcome {
  const ScanOutcome();
}

class ScannedCode extends ScanOutcome {
  final String raw;
  const ScannedCode(this.raw);
}

/// Operator memilih input manual dari layar scanner.
class ManualInputRequested extends ScanOutcome {
  const ManualInputRequested();
}

class CameraUnavailable extends ScanOutcome {
  final CameraProblem problem;
  const CameraUnavailable(this.problem);

  String get message => switch (problem) {
        CameraProblem.permissionDenied =>
          'Izin kamera ditolak. Izinkan kamera di pengaturan HP atau '
              'browser, atau masukkan barang secara manual.',
        CameraProblem.unavailable =>
          'Kamera tidak tersedia di perangkat ini. Masukkan barang secara '
              'manual.',
      };
}

/// Cara membuka scanner. Disediakan lewat `provider` supaya test bisa
/// menggantinya tanpa kamera.
typedef ScanLauncher = Future<ScanOutcome?> Function(BuildContext context);
