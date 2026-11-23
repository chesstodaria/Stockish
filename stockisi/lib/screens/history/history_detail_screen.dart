import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/transaction_repository.dart';
import '../../models/transaction_record.dart';
import '../../services/formatters.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/history_detail_view_model.dart';
import '../../widgets/document_type_badge.dart';
import '../../widgets/state_views.dart';

/// Detail Riwayat Transaksi (layar 12): header transaksi dan tabel item.
class HistoryDetailScreen extends StatelessWidget {
  final String transactionNumber;

  const HistoryDetailScreen({super.key, required this.transactionNumber});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => HistoryDetailViewModel(
        ctx.read<TransactionRepository>(),
        transactionNumber,
      )..load(),
      child: const _HistoryDetailView(),
    );
  }
}

class _HistoryDetailView extends StatelessWidget {
  const _HistoryDetailView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HistoryDetailViewModel>();
    final record = vm.record;

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Riwayat')),
      body: _buildBody(vm, record),
    );
  }

  Widget _buildBody(HistoryDetailViewModel vm, TransactionRecord? record) {
    if (vm.loading && record == null) {
      return const LoadingView(message: 'Memuat transaksi...');
    }
    if (vm.notFound) {
      return EmptyView(
        icon: Icons.receipt_long_outlined,
        title: 'Transaksi tidak ditemukan',
        message: vm.error ??
            'Transaksi ini tidak ada atau bukan milik gudang Anda.',
      );
    }
    if (vm.error != null && record == null) {
      return ErrorView(
        message: vm.error!,
        title: 'Gagal memuat transaksi',
        onRetry: vm.load,
      );
    }
    if (record == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.screen,
        AppSpace.screen,
        AppSpace.xxl,
      ),
      children: [
        _HeaderCard(record: record),
        const SizedBox(height: AppSpace.xl),
        _ItemTable(lines: record.lines),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final TransactionRecord record;

  const _HeaderCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final r = record;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DocumentTypeBadge(r.type, showLabel: true),
                const Spacer(),
                if (!r.closedDocument)
                  Text(
                    'Dokumen masih terbuka',
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.partialFg),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              r.number,
              style: AppTextStyles.headline,
            ),
            const SizedBox(height: AppSpace.lg),
            _HeaderRow(label: 'Dokumen', value: r.documentNumber),
            _HeaderRow(
              label: 'Waktu submit',
              value: Fmt.dateTime(r.submittedAt),
            ),
            _HeaderRow(
              label: 'Operator',
              value: '${r.operatorName} (${r.operatorNik})',
            ),
            _HeaderRow(label: 'Gudang', value: r.warehouseCode),
            if (r.vendorDeliveryNo != null)
              _HeaderRow(
                label: 'Surat jalan',
                value: r.vendorDeliveryNo!,
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(label, style: AppTextStyles.bodySecondary),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(value, style: AppTextStyles.bodyStrong)),
        ],
      ),
    );
  }
}

class _ItemTable extends StatelessWidget {
  final List<TransactionLine> lines;

  const _ItemTable({required this.lines});

  @override
  Widget build(BuildContext context) {
    final shown = lines.where((l) => !l.markedUnavailable).length;
    final unavailable = lines.length - shown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Item', style: AppTextStyles.title),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                unavailable == 0
                    ? '$shown item'
                    : '$shown item, $unavailable tidak tersedia',
                style: AppTextStyles.bodySecondary,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < lines.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _ItemRow(line: lines[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final TransactionLine line;

  const _ItemRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final unavailable = line.markedUnavailable;
    return Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.itemName,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: unavailable
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '${line.itemCode}  •  Rak ${line.rackNumber}',
                  style: AppTextStyles.code,
                ),
                if (unavailable) ...[
                  const SizedBox(height: AppSpace.sm),
                  _UnavailableTag(),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.qty(line.quantity),
                style: AppTextStyles.quantity.copyWith(
                  color: unavailable
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
              Text(line.uom, style: AppTextStyles.bodySecondary),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnavailableTag extends StatelessWidget {
  const _UnavailableTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.pendingBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.block_rounded,
            size: 14,
            color: AppColors.pendingFg,
          ),
          const SizedBox(width: AppSpace.xs),
          Text(
            'Tidak tersedia',
            style: AppTextStyles.chip.copyWith(color: AppColors.pendingFg),
          ),
        ],
      ),
    );
  }
}
