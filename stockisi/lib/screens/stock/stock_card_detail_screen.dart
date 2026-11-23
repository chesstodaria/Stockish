import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/stock_card_repository.dart';
import '../../models/document_type.dart';
import '../../models/stock_item.dart';
import '../../models/stock_movement.dart';
import '../../services/formatters.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/stock_card_detail_view_model.dart';
import '../../widgets/document_type_badge.dart';
import '../../widgets/state_views.dart';
import '../app_routes.dart';

/// Detail Kartu Stok (layar 9): informasi barang, saldo stok, dan riwayat
/// mutasi Receiving dan Intransit.
class StockCardDetailScreen extends StatelessWidget {
  final String itemCode;

  const StockCardDetailScreen({super.key, required this.itemCode});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => StockCardDetailViewModel(
        ctx.read<StockCardRepository>(),
        itemCode,
      )..load(),
      child: const _StockCardDetailView(),
    );
  }
}

class _StockCardDetailView extends StatelessWidget {
  const _StockCardDetailView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StockCardDetailViewModel>();
    final item = vm.item;

    return Scaffold(
      appBar: AppBar(title: Text(vm.item?.itemCode ?? 'Kartu Stok')),
      body: _buildBody(context, vm, item),
    );
  }

  Widget _buildBody(
    BuildContext context,
    StockCardDetailViewModel vm,
    StockItem? item,
  ) {
    if (vm.loading && item == null) {
      return const LoadingView(message: 'Memuat kartu stok...');
    }
    if (vm.notFound) {
      return EmptyView(
        icon: Icons.inventory_2_outlined,
        title: 'Barang tidak ditemukan',
        message: vm.error ??
            'Barang ini tidak ada di gudang Anda.',
      );
    }
    if (vm.error != null && item == null) {
      return ErrorView(
        message: vm.error!,
        title: 'Gagal memuat kartu stok',
        onRetry: vm.load,
      );
    }
    if (item == null) return const SizedBox.shrink();

    final movements = vm.movements ?? const <StockMovement>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.screen,
        AppSpace.screen,
        AppSpace.xxl,
      ),
      children: [
        _ItemHeader(item: item),
        const SizedBox(height: AppSpace.xl),
        Row(
          children: [
            Text('Riwayat mutasi', style: AppTextStyles.title),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                movements.isEmpty ? '' : '${movements.length} catatan',
                style: AppTextStyles.bodySecondary,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        if (movements.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
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
                      'Barang ini belum punya riwayat mutasi. Mutasi tercatat '
                      'setelah transaksi Receiving atau Intransit disubmit.',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < movements.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _MovementRow(movement: movements[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ItemHeader extends StatelessWidget {
  final StockItem item;

  const _ItemHeader({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.itemName, style: AppTextStyles.headline),
            const SizedBox(height: AppSpace.xs),
            Text(item.itemCode, style: AppTextStyles.code),
            const SizedBox(height: AppSpace.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpace.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Saldo stok fisik', style: AppTextStyles.bodySecondary),
                  const SizedBox(height: AppSpace.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        Fmt.qty(item.balance),
                        style: AppTextStyles.quantityLarge,
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Text(item.uom, style: AppTextStyles.bodyStrong),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: AppSize.iconSm,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpace.xs),
                Text('Rak ${item.rackNumber}',
                    style: AppTextStyles.bodySecondary),
                const Spacer(),
                Text(item.warehouseCode, style: AppTextStyles.code),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed(
                  AppRoutes.qrLabel,
                  arguments: item.itemCode,
                ),
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('Label QR'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  final StockMovement movement;

  const _MovementRow({required this.movement});

  @override
  Widget build(BuildContext context) {
    final m = movement;
    final incoming = m.type == DocumentType.receiving;
    final color = incoming ? AppColors.receivingFg : AppColors.intransitFg;

    return Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DocumentTypeBadge(m.type),
                    const SizedBox(width: AppSpace.sm),
                    Flexible(
                      child: Text(
                        Fmt.dateTime(m.date),
                        style: AppTextStyles.bodySecondary,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '${m.documentNumber}  •  ${m.transactionNumber}',
                  style: AppTextStyles.code,
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  incoming
                      ? 'Masuk dari Receiving · NIK ${m.operatorNik}'
                      : 'Keluar untuk Intransit · NIK ${m.operatorNik}',
                  style: AppTextStyles.bodySecondary,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${incoming ? '+' : '−'}${Fmt.qty(m.quantity)}',
                style: AppTextStyles.quantity.copyWith(color: color),
              ),
              Text(
                'saldo ${Fmt.qty(m.balanceAfter)}',
                style: AppTextStyles.code,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
