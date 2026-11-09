import 'package:flutter/material.dart';
import '../models/stock_item.dart';
import '../widgets/stock_card_attachment_placeholder.dart';

class StockCardEngineeringDrawingsScreen extends StatelessWidget {
  final StockItem item;
  final String token; // BARU (24 Juli 2026) — disiapkan, belum dipakai. Lihat 05_Decision_Log.md.

  const StockCardEngineeringDrawingsScreen({super.key, required this.item, required this.token});

  @override
  Widget build(BuildContext context) {
    return StockCardAttachmentPlaceholder(
      title: 'Engineering Drawings',
      icon: Icons.architecture_outlined,
      item: item,
      description:
          'Gambar teknik/CAD akan ditampilkan di sini begitu tersambung '
          'ke ERP.',
    );
  }
}