import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/stock_card_repository.dart';
import '../../models/stock_item.dart';
import '../../services/formatters.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/stock_card_list_view_model.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/pressable.dart';
import '../../widgets/section_header.dart';
import '../../widgets/state_views.dart';
import '../app_routes.dart';

/// Tab Kartu Stok: Daftar Kartu Stok (layar 8).
///
/// Data barang seragam dan tidak punya state per baris, jadi dipakai daftar
/// bergaya *inset grouped* iOS: satu permukaan, pemisah tipis, saldo besar
/// di kanan.
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
    await vm.load(silent: true);
  }

  void _clear(StockCardListViewModel vm) {
    _search.clear();
    vm.clearQuery();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StockCardListViewModel>();
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.screen, AppSpace.md, AppSpace.screen, 0),
            child: Column(
              children: [
                const AppHeader(title: 'Kartu Stok'),
                const SizedBox(height: AppSpace.lg),
                AppSearchField(
                  controller: _search,
                  hint: 'Cari nama atau kode barang',
                  onChanged: vm.setQuery,
                  showClear: vm.query.isNotEmpty,
                  onClear: () => _clear(vm),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Expanded(child: _buildBody(vm)),
        ],
      ),
    );
  }

  Widget _buildBody(StockCardListViewModel vm) {
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
        child: ListView(children: const [
          SizedBox(height: AppSpace.xxl),
          EmptyView(
            icon: Icons.inventory_2_outlined,
            title: 'Belum ada barang',
            message: 'Barang untuk gudang Anda akan muncul di sini setelah '
                'ada penerimaan barang.',
          ),
        ]),
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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.screen,
          0,
          AppSpace.screen,
          AppSpace.xl,
        ),
        children: [
          vm.query.trim().isEmpty
              ? SectionHeader('Barang', trailing: '${items.length}')
              : SectionHeader('Hasil pencarian', trailing: '${items.length}'),
          const SizedBox(height: AppSpace.sm),
          GroupedList(
            children: [
              for (final item in items)
                Pressable(
                  onTap: () => _open(item),
                  child: GroupedRow(child: _ItemRow(item: item)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final StockItem item;

  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.itemName, style: AppTextStyles.bodyStrong),
              const SizedBox(height: 2),
              Text(
                '${item.itemCode}  ·  Rak ${item.rackNumber}',
                style: AppTextStyles.code,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Fmt.qty(item.balance),
              style: AppTextStyles.quantity.copyWith(
                color: item.balance == 0
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
            Text(item.uom, style: AppTextStyles.code),
          ],
        ),
      ],
    );
  }
}
