import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/stock_card_repository.dart';
import '../../models/stock_item.dart';
import '../../services/formatters.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/stock_card_list_view_model.dart';
import '../../widgets/state_views.dart';
import '../app_routes.dart';

/// Tab Kartu Stok: Daftar Kartu Stok (layar 8). Pencarian nama atau kode
/// sebagai fokus utama, hanya barang di gudang operator.
class StockCardListScreen extends StatelessWidget {
  const StockCardListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => StockCardListViewModel(
        ctx.read<StockCardRepository>(),
      )..load(),
      child: const _StockCardListView(),
    );
  }
}

class _StockCardListView extends StatefulWidget {
  const _StockCardListView();

  @override
  State<_StockCardListView> createState() => _StockCardListViewState();
}

class _StockCardListViewState extends State<_StockCardListView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(StockItem item) async {
    final vm = context.read<StockCardListViewModel>();
    await Navigator.of(context).pushNamed(
      AppRoutes.stockCardDetail,
      arguments: item.itemCode,
    );
    // Saldo bisa berubah kalau operator submit transaksi di tab lain.
    await vm.load(silent: true);
  }

  void _clear(StockCardListViewModel vm) {
    _search.clear();
    vm.clearQuery();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StockCardListViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Kartu Stok')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.screen,
              0,
              AppSpace.screen,
              AppSpace.md,
            ),
            child: TextField(
              controller: _search,
              onChanged: vm.setQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari nama atau kode barang',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: vm.query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus pencarian',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => _clear(vm),
                      ),
              ),
            ),
          ),
          Expanded(child: _buildBody(context, vm)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, StockCardListViewModel vm) {
    final items = vm.items;

    if (vm.loading && items == null) {
      return const LoadingView(message: 'Memuat kartu stok...');
    }
    if (vm.error != null && items == null) {
      return ErrorView(
        message: vm.error!,
        title: 'Gagal memuat kartu stok',
        onRetry: vm.load,
      );
    }
    if (items == null) return const SizedBox.shrink();

    if (vm.warehouseEmpty) {
      return RefreshIndicator(
        onRefresh: () => vm.load(silent: true),
        child: ListView(
          children: const [
            SizedBox(height: AppSpace.xxl),
            EmptyView(
              icon: Icons.inventory_2_outlined,
              title: 'Belum ada barang',
              message: 'Barang untuk gudang Anda akan muncul di sini setelah '
                  'ada penerimaan barang.',
            ),
          ],
        ),
      );
    }

    if (vm.noMatch) {
      return EmptyView(
        icon: Icons.search_off_rounded,
        title: 'Barang tidak ditemukan',
        message: 'Tidak ada barang dengan kata kunci "${vm.query.trim()}" '
            'di gudang Anda.',
        actionLabel: 'Hapus pencarian',
        onAction: () => _clear(vm),
      );
    }

    return RefreshIndicator(
      onRefresh: () => vm.load(silent: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.screen,
          AppSpace.sm,
          AppSpace.screen,
          AppSpace.xl,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
        itemBuilder: (_, i) => _StockItemCard(
          item: items[i],
          onTap: () => _open(items[i]),
        ),
      ),
    );
  }
}

class _StockItemCard extends StatelessWidget {
  final StockItem item;
  final VoidCallback onTap;

  const _StockItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final i = item;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.itemName, style: AppTextStyles.title),
                    const SizedBox(height: AppSpace.xs),
                    Text(i.itemCode, style: AppTextStyles.code),
                    const SizedBox(height: AppSpace.sm),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: AppSize.iconSm,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpace.xs),
                        Text(
                          'Rak ${i.rackNumber}',
                          style: AppTextStyles.bodySecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Fmt.qty(i.balance),
                    style: AppTextStyles.quantity.copyWith(
                      color: i.balance == 0
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(i.uom, style: AppTextStyles.bodySecondary),
                ],
              ),
              const SizedBox(width: AppSpace.xs),
              const Padding(
                padding: EdgeInsets.only(top: AppSpace.xs),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
