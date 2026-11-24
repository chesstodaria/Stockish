import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/transaction_repository.dart';
import '../../models/transaction_record.dart';
import '../../services/formatters.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/history_list_view_model.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_pill.dart';
import '../../widgets/pressable.dart';
import '../../widgets/section_header.dart';
import '../../widgets/state_views.dart';
import '../../widgets/type_pill.dart';
import '../app_routes.dart';

/// Tab Riwayat: Riwayat Transaksi (layar 11).
///
/// Transaksi dikelompokkan per bulan. Pengelompokan ini yang membuat daftar
/// panjang tetap terbaca tanpa perlu kolom pencarian.
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
    await vm.load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HistoryListViewModel>();
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpace.screen, AppSpace.md, AppSpace.screen, AppSpace.lg),
            child: AppHeader(title: 'Riwayat'),
          ),
          Expanded(child: _buildBody(context, vm)),
        ],
      ),
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
        child: ListView(children: const [
          SizedBox(height: AppSpace.xxl),
          EmptyView(
            icon: Icons.history_rounded,
            title: 'Belum ada transaksi',
            message: 'Transaksi yang sudah disubmit akan muncul di sini. '
                'Selesaikan satu dokumen di tab Dokumen untuk mencobanya.',
          ),
        ]),
      );
    }

    // Kelompokkan per bulan, urutan tetap terbaru dulu.
    final groups = <String, List<TransactionRecord>>{};
    for (final r in records) {
      groups.putIfAbsent(_monthLabel(r.submittedAt), () => []).add(r);
    }

    final children = <Widget>[];
    var first = true;
    for (final entry in groups.entries) {
      if (!first) children.add(const SizedBox(height: AppSpace.xl));
      first = false;
      children.add(SectionHeader(entry.key, trailing: '${entry.value.length}'));
      children.add(const SizedBox(height: AppSpace.sm));
      for (var i = 0; i < entry.value.length; i++) {
        if (i > 0) children.add(const SizedBox(height: AppSpace.sm + 2));
        final record = entry.value[i];
        children.add(_TransactionCard(
          record: record,
          onTap: () => _open(context, record),
        ));
      }
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
        children: children,
      ),
    );
  }

  static const _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  static String _monthLabel(DateTime d) => '${_months[d.month - 1]} ${d.year}';
}

class _TransactionCard extends StatelessWidget {
  final TransactionRecord record;
  final VoidCallback onTap;

  const _TransactionCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = record;
    final accent = TypePill.foreground(r.type);
    final itemCount = r.lines.where((l) => !l.markedUnavailable).length;

    return Pressable(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg - 2),
          side: const BorderSide(color: AppColors.border),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.lg,
                    vertical: AppSpace.md + 2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(r.number, style: AppTextStyles.title),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(r.documentNumber,
                          style: AppTextStyles.bodySecondary),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        '${r.type.code}  ·  ${Fmt.dateTime(r.submittedAt)}  ·  '
                        '$itemCount item',
                        style: AppTextStyles.code.copyWith(color: accent),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.operatorName,
                              style: AppTextStyles.code,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!r.closedDocument)
                            AppPill(
                              label: 'Dokumen terbuka',
                              background: AppColors.partialBg,
                              foreground: AppColors.partialFg,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
