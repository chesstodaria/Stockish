import 'package:flutter/material.dart';
import '../models/stock_item.dart';
import '../widgets/stock_card_attachment_placeholder.dart';

class StockCard3DScreen extends StatelessWidget {
  final StockItem item;
  final String token; // BARU (24 Juli 2026) — disiapkan, belum dipakai. Lihat 05_Decision_Log.md.

  const StockCard3DScreen({super.key, required this.item, required this.token});

  @override
  Widget build(BuildContext context) {
    return StockCardAttachmentPlaceholder(
      title: '3D',
      icon: Icons.view_in_ar_outlined,
      item: item,
      description:
          'Model 3D barang akan ditampilkan di sini begitu tersambung '
          'ke ERP.',
    );
  }
}