import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';
import '../app_routes.dart';

/// Tab Kartu Stok: Daftar Kartu Stok (layar 8). Placeholder Tahap 1.
class StockCardListScreen extends StatelessWidget {
  const StockCardListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Kartu Stok',
      stage: 'Tahap 4',
      description: 'Kolom pencarian nama atau kode sebagai fokus utama, '
          'hanya barang di gudang operator.',
      links: [
        PlaceholderLink(
          'Buka Detail Kartu Stok (contoh)',
          () => Navigator.of(context).pushNamed(
            AppRoutes.stockCardDetail,
            arguments: 'BRG-0001',
          ),
        ),
      ],
    );
  }
}
