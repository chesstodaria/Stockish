import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

/// Detail Riwayat Transaksi (layar 12). Placeholder Tahap 1.
class HistoryDetailScreen extends StatelessWidget {
  final String transactionNumber;

  const HistoryDetailScreen({super.key, required this.transactionNumber});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: transactionNumber,
      stage: 'Tahap 5',
      description: 'Header transaksi dan tabel item.',
    );
  }
}
