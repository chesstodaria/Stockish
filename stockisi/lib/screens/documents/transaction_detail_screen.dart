import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';
import '../app_routes.dart';

/// Detail Transaksi (layar 5). Placeholder Tahap 1.
class TransactionDetailScreen extends StatelessWidget {
  final String documentNumber;

  const TransactionDetailScreen({super.key, required this.documentNumber});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: documentNumber,
      stage: 'Tahap 3',
      description: 'Progres di atas, kartu item, tombol Scan besar di '
          'bawah, input manual, ubah dan hapus item, penahan tombol kembali.',
      links: [
        PlaceholderLink(
          'Buka Scan QR',
          () => Navigator.of(context).pushNamed(AppRoutes.scanner),
        ),
        PlaceholderLink(
          'Buka Ringkasan Transaksi',
          () => Navigator.of(context).pushNamed(
            AppRoutes.transactionSummary,
            arguments: documentNumber,
          ),
        ),
      ],
    );
  }
}
