import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/transaction_repository.dart';
import '../../models/transaction_record.dart';
import '../../services/formatters.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/history_list_view_model.dart';
import '../../widgets/document_type_badge.dart';
import '../../widgets/state_views.dart';
import '../app_routes.dart';

/// Tab Riwayat: Riwayat Transaksi (layar 11). Hanya transaksi SUBMITTED di
/// gudang operator, terbaru dulu, dengan badge RCV atau INT.
class HistoryListScreen extends StatelessWidget {
  const HistoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => HistoryListViewModel(
        ctx.read<TransactionRepository>(),
      )..load(),
      child: const _HistoryListView(),
    );
  }
}

class _HistoryListView extends StatelessWidget {
  const _HistoryListView();

  Future<void> _open(BuildContext context, TransactionRecord record) async {
    final vm = context.read<HistoryListViewModel>();
    await Navigator.of(context).pushNamed(
      AppRoutes.historyDetail,
      arguments: record.number,
    );
    // Transaksi baru bisa muncul selama layar detail terbuka.
    await vm.load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HistoryListViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat')),
      body: _buildBody(context, vm),
    );
  }

  Widget _buildBody(BuildContext context, HistoryListViewModel vm) {
    final records = vm.records;

    if (vm.loading && records == null) {
      return const LoadingView(message: 'Memuat riwayat transaksi...');
    }
    if (vm.error != null && records == null) {
      return ErrorView(
        message: vm.error!,
        title: 'Gagal memuat riwayat',
        onRetry: vm.load,
      );
    }
    if (records == null) return const SizedBox.shrink();

    if (records.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => vm.load(silent: true),
        child: ListView(
          children: const [
            SizedBox(height: AppSpace.xxl),
            EmptyView(
              icon: Icons.history_rounded,
              title: 'Belum ada transaksi',
              message: 'Transaksi yang sudah disubmit akan muncul di sini. '
                  'Selesaikan satu dokumen di tab Dokumen untuk mencobanya.',
            ),
          ],
        ),
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
        itemCount: records.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
        itemBuilder: (_, i) => _TransactionCard(
          record: records[i],
          onTap: () => _open(context, records[i]),
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final TransactionRecord record;
  final VoidCallback onTap;

  const _TransactionCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = record;
    final itemCount = r.lines.where((l) => !l.markedUnavailable).length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DocumentTypeBadge(r.type),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      r.number,
                      style: AppTextStyles.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xs),
              Text(r.documentNumber, style: AppTextStyles.bodySecondary),
              const SizedBox(height: AppSpace.xs),
              Text(
                '${Fmt.dateTime(r.submittedAt)}  •  $itemCount item',
                style: AppTextStyles.code,
              ),
              const SizedBox(height: AppSpace.xs),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: AppSize.iconSm,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: Text(
                      r.operatorName,
                      style: AppTextStyles.bodySecondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!r.closedDocument)
                    const _OpenDocumentTag(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Penanda bahwa submit ini hanya menyimpan Partial, jadi dokumennya masih
/// terbuka untuk sisa barang (CONTEXT 6).
class _OpenDocumentTag extends StatelessWidget {
  const _OpenDocumentTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.partialBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'Dokumen masih terbuka',
        style: AppTextStyles.chip.copyWith(color: AppColors.partialFg),
      ),
    );
  }
}
