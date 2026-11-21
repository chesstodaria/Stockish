import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

/// Ringkasan Transaksi (layar 6) beserta dialog Konfirmasi Submit
/// (layar 7). Placeholder Tahap 1.
class TransactionSummaryScreen extends StatelessWidget {
  final String documentNumber;

  const TransactionSummaryScreen({super.key, required this.documentNumber});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Ringkasan Transaksi',
      stage: 'Tahap 3',
      description: 'Rekap item, nomor surat jalan untuk RCV, dialog '
          'Konfirmasi Submit (Simpan sebagai Partial atau Tandai Selesai), '
          'dan konfirmasi berhasil.',
    );
  }
}
