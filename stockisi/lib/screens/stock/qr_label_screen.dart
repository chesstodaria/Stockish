import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/stock_card_repository.dart';
import '../../models/stock_item.dart';
import '../../services/qr_payload.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/state_views.dart';

/// Label QR Code (layar 10). QR hanya ditampilkan di layar, tidak dicetak
/// (laporan 2.2.5 dan CONTEXT 4.1).
class QrLabelScreen extends StatefulWidget {
  final String itemCode;

  const QrLabelScreen({super.key, required this.itemCode});

  @override
  State<QrLabelScreen> createState() => _QrLabelScreenState();
}

class _QrLabelScreenState extends State<QrLabelScreen> {
  late Future<StockItem> _item;

  @override
  void initState() {
    super.initState();
    _item = context.read<StockCardRepository>().getItem(widget.itemCode);
  }

  void _reload() {
    setState(() {
      _item = context.read<StockCardRepository>().getItem(widget.itemCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Label QR')),
      body: FutureBuilder<StockItem>(
        future: _item,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Menyiapkan label...');
          }
          final error = snapshot.error;
          if (error != null || snapshot.data == null) {
            return EmptyView(
              icon: Icons.qr_code_2_outlined,
              title: 'Label tidak bisa dibuat',
              message: 'Barang tidak ditemukan di gudang Anda.',
              actionLabel: 'Coba lagi',
              onAction: _reload,
            );
          }
          return _LabelContent(item: snapshot.data!);
        },
      ),
    );
  }
}

class _LabelContent extends StatelessWidget {
  final StockItem item;

  const _LabelContent({required this.item});

  @override
  Widget build(BuildContext context) {
    final payload = QrPayload(
      itemCode: item.itemCode,
      uom: item.uom,
      warehouseCode: item.warehouseCode,
    ).encode();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.xl,
        AppSpace.screen,
        AppSpace.xxl,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.xl),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpace.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: CustomPaint(painter: _QrPainter(payload)),
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Text(
                      item.itemName,
                      style: AppTextStyles.title,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(item.itemCode, style: AppTextStyles.code),
                    const SizedBox(height: AppSpace.md),
                    _PayloadText(payload: payload),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        _InfoRow(label: 'Satuan', value: item.uom),
        _InfoRow(label: 'Gudang', value: item.warehouseCode),
        _InfoRow(label: 'Nomor rak', value: item.rackNumber),
        const SizedBox(height: AppSpace.xl),
        Container(
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(
                  'Label ini hanya ditampilkan di layar. Pencetakan ke printer '
                  'tidak termasuk cakupan aplikasi. Scanner di Detail Transaksi '
                  'membaca format yang sama.',
                  style: AppTextStyles.bodySecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Isi QR ditulis apa adanya supaya bisa dicek tanpa memindai.
class _PayloadText extends StatelessWidget {
  final String payload;

  const _PayloadText({required this.payload});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        payload,
        style: AppTextStyles.code.copyWith(color: AppColors.textPrimary),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodySecondary)),
          Text(value, style: AppTextStyles.bodyStrong),
        ],
      ),
    );
  }
}

/// Menggambar QR dari paket `barcode`. Tidak memakai layanan gambar daring,
/// jadi label tetap tampil tanpa koneksi.
class _QrPainter extends CustomPainter {
  final String data;

  _QrPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = AppColors.surface;
    canvas.drawRect(Offset.zero & size, background);

    final ink = Paint()..color = AppColors.textPrimary;
    final elements = Barcode.qrCode().make(
      data,
      width: size.width,
      height: size.height,
    );
    for (final element in elements) {
      if (element is BarcodeBar && element.black) {
        canvas.drawRect(
          Rect.fromLTWH(
            element.left,
            element.top,
            element.width,
            element.height,
          ),
          ink,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => oldDelegate.data != data;
}
