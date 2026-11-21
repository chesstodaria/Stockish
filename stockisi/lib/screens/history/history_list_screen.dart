import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';
import '../app_routes.dart';

/// Tab Riwayat: Riwayat Transaksi (layar 11). Placeholder Tahap 1.
class HistoryListScreen extends StatelessWidget {
  const HistoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Riwayat',
      stage: 'Tahap 5',
      description: 'Transaksi SUBMITTED di gudang operator dengan badge '
          'RCV atau INT.',
      links: [
        PlaceholderLink(
          'Buka Detail Riwayat (contoh)',
          () => Navigator.of(context).pushNamed(
            AppRoutes.historyDetail,
            arguments: 'TRX-RCV-261007-0001',
          ),
        ),
      ],
    );
  }
}
