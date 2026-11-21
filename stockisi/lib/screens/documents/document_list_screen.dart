import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';
import '../app_routes.dart';

/// Tab Dokumen: Daftar Dokumen Referensi (layar 4). Placeholder Tahap 1.
class DocumentListScreen extends StatelessWidget {
  const DocumentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Dokumen',
      stage: 'Tahap 3',
      description: 'Segmen RCV/INT, pencarian, filter status, progres '
          'Partial, dan penanda draf.',
      links: [
        PlaceholderLink(
          'Buka Detail Transaksi (contoh)',
          () => Navigator.of(context).pushNamed(
            AppRoutes.transactionDetail,
            arguments: 'PO-2611-0041',
          ),
        ),
      ],
    );
  }
}
