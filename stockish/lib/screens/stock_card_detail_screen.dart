import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../models/stock_item.dart';
import '../models/stock_movement.dart';
import '../repositories/stock_card_repository.dart';
import 'stock_card_goods_screen.dart';
import 'stock_card_technical_info_screen.dart';
import 'stock_card_engineering_drawings_screen.dart';
import 'stock_card_3d_screen.dart';

class StockCardDetailScreen extends StatefulWidget {
  final StockItem item;
  final String token;

  const StockCardDetailScreen({super.key, required this.item, required this.token});

  @override
  State<StockCardDetailScreen> createState() => _StockCardDetailScreenState();
}

class _StockCardDetailScreenState extends State<StockCardDetailScreen> {
  final StockCardRepository _repository = StockCardRepository();
  late final Future<List<StockMovement>> _movementsFuture;

  // BARU (12 Agustus 2026) — toggle "Show More" Extension Field, pola sama
  // Transaction Detail (transaction_detail_screen.dart). Beda dari sana
  // (StatefulBuilder di dalam modal), di sini pakai setState() biasa karena
  // ini State Screen penuh, bukan builder di dalam showModalBottomSheet.
  bool _showExtensionFields = false;

  @override
  void initState() {
    super.initState();
    _movementsFuture = _repository.getMovements(widget.item.itemCode, token: widget.token);
  }

  String _formatDate(DateTime date) => DateFormat('dd MMM yyyy').format(date);

  /// Popup 4 kategori dokumen (Goods/Technical Information/Engineering
  /// Drawings/3D) + Foto. Tiap tile navigasi ke Screen placeholder-nya
  /// sendiri (lihat perubahan 19 Juli 2026 sebelumnya).
  ///
  /// Layout direvisi (19 Juli 2026, prioritas #4): sebelumnya foto ada di
  /// bawah grid dan seluruh isi dibungkus SingleChildScrollView — di layar
  /// lebih kecil (phone) itu perlu di-scroll buat lihat semuanya. Sekarang:
  /// foto dipindah ke ATAS (fixed height ringkas, 100px) biar langsung
  /// kelihatan tanpa scroll, grid 4 tile mengisi sisa ruang lewat Expanded,
  /// dan tinggi popup total dihitung proporsional dari tinggi layar
  /// (MediaQuery, di-clamp 420-600px) — bukan angka fixed — supaya
  /// proporsinya konsisten baik di tablet maupun phone. Tombol "Tutup" di
  /// bawah dihapus (redundan dengan icon close di header), murni buat
  /// menghemat ruang vertikal.
  void _showAttachmentsPopup(BuildContext context, StockItem item) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final popupHeight = (screenHeight * 0.62).clamp(420.0, 600.0);
    final popupWidth = (screenWidth * 0.9).clamp(280.0, 420.0);

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: popupWidth, maxHeight: popupHeight),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.itemName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(item.itemCode, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(dialogContext).pop(),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Foto — dipindah ke atas (sebelumnya di bawah grid), fixed
                // height ringkas biar sisa ruang vertikal cukup buat grid
                // 2x2 tanpa perlu scroll.
                Container(
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 20),
                        SizedBox(width: 8),
                        Text('Foto belum tersedia', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _attachmentTile(
                        context,
                        'Goods',
                        Icons.inventory_2_outlined,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => StockCardGoodsScreen(item: item, token: widget.token)),
                        ),
                      ),
                      _attachmentTile(
                        context,
                        'Technical Information',
                        Icons.description_outlined,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => StockCardTechnicalInfoScreen(item: item, token: widget.token)),
                        ),
                      ),
                      _attachmentTile(
                        context,
                        'Engineering Drawings',
                        Icons.architecture_outlined,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => StockCardEngineeringDrawingsScreen(item: item, token: widget.token)),
                        ),
                      ),
                      _attachmentTile(
                        context,
                        '3D',
                        Icons.view_in_ar_outlined,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => StockCard3DScreen(item: item, token: widget.token)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _attachmentTile(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: kPrimaryColor, size: 28),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  // BARU (12 Agustus 2026) — box "Show More" Extension Field, pola sama
  // persis Transaction Detail (transaction_detail_screen.dart).
  Widget _extensionFieldsSection(StockItem item) {
    if (item.extensionFields.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        InkWell(
          onTap: () => setState(() => _showExtensionFields = !_showExtensionFields),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _showExtensionFields ? 'Sembunyikan Detail' : 'Show More',
                style: const TextStyle(
                  color: kPrimaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Icon(
                _showExtensionFields ? Icons.expand_less : Icons.expand_more,
                color: kPrimaryColor,
                size: 18,
              ),
            ],
          ),
        ),
        if (_showExtensionFields) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: item.extensionFields
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text(
                              f.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(f.value, style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Detail Stock Card', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.itemName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(item.itemCode, style: TextStyle(color: Colors.grey.shade600)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 18, color: kPrimaryColor),
                              const SizedBox(width: 6),
                              Text('Stok Saat Ini: ${item.currentStock} ${item.unit}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.shelves, size: 18, color: kPrimaryColor),
                              const SizedBox(width: 6),
                              Text('Rak: ${item.rackNumber}', style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white, // warna teks/icon
                      ),
                      onPressed: () => _showAttachmentsPopup(context, item),
                      child: const Text('Detail'),
                    )
                  ],
                ),
                _extensionFieldsSection(item),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(alignment: Alignment.centerLeft, child: Text('Riwayat Pergerakan', style: TextStyle(fontWeight: FontWeight.bold))),
          ),
          Expanded(
            child: FutureBuilder<List<StockMovement>>(
              future: _movementsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final movements = snapshot.data ?? [];
                if (movements.isEmpty) {
                  return const Center(child: Text('Belum ada riwayat pergerakan.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: movements.length,
                  itemBuilder: (context, index) {
                    final m = movements[index];
                    final isReceiving = m.type == StockMovementType.receiving;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(isReceiving ? Icons.arrow_downward : Icons.arrow_upward, color: isReceiving ? Colors.green : Colors.orange),
                        title: Text(m.referenceNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(_formatDate(m.date)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${isReceiving ? '+' : '-'}${m.quantity}', style: TextStyle(fontWeight: FontWeight.bold, color: isReceiving ? Colors.green : Colors.orange)),
                            Text('Saldo: ${m.balanceAfter}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}