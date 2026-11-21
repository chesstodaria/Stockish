import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';
import '../app_routes.dart';

/// Detail Kartu Stok (layar 9). Placeholder Tahap 1.
class StockCardDetailScreen extends StatelessWidget {
  final String itemCode;

  const StockCardDetailScreen({super.key, required this.itemCode});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: itemCode,
      stage: 'Tahap 4',
      description: 'Saldo, satuan, nomor rak, dan riwayat mutasi Receiving '
          'dan Intransit.',
      links: [
        PlaceholderLink(
          'Buka Label QR',
          () => Navigator.of(context)
              .pushNamed(AppRoutes.qrLabel, arguments: itemCode),
        ),
      ],
    );
  }
}
