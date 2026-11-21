import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

/// Scan QR kamera. Placeholder Tahap 1.
class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Scan QR',
      stage: 'Tahap 3',
      description: 'Kamera membaca QR format kode|satuan|gudang. Izin '
          'ditolak atau kamera tidak tersedia mengarah ke input manual.',
    );
  }
}
