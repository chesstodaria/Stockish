import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

/// Label QR Code (layar 10). Placeholder Tahap 1.
class QrLabelScreen extends StatelessWidget {
  final String itemCode;

  const QrLabelScreen({super.key, required this.itemCode});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Label QR $itemCode',
      stage: 'Tahap 4',
      description: 'QR berisi kode|satuan|gudang, hanya ditampilkan di layar.',
    );
  }
}
