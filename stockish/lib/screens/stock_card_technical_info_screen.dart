import 'package:flutter/material.dart';
import '../models/stock_item.dart';
import '../widgets/stock_card_attachment_placeholder.dart';

class StockCardTechnicalInfoScreen extends StatelessWidget {
  final StockItem item;
  final String token; // BARU (24 Juli 2026) — disiapkan, belum dipakai. Lihat 05_Decision_Log.md.

  const StockCardTechnicalInfoScreen({super.key, required this.item, required this.token});

  @override
  Widget build(BuildContext context) {
    return StockCardAttachmentPlaceholder(
      title: 'Technical Information',
      icon: Icons.description_outlined,
      item: item,
      description:
          'Dokumen teknis (spesifikasi material, datasheet, dll) akan '
          'ditampilkan di sini begitu tersambung ke ERP.',
    );
  }
}