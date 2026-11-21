import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/draft_repository.dart';
import '../../data/repositories/reference_document_repository.dart';
import '../../models/document_type.dart';
import '../../models/reference_document.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/document_list_view_model.dart';
import '../../widgets/document_card.dart';
import '../../widgets/document_type_badge.dart';
import '../../widgets/state_views.dart';
import '../app_routes.dart';

/// Tab Dokumen: Daftar Dokumen Referensi (layar 4).
class DocumentListScreen extends StatelessWidget {
  const DocumentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => DocumentListViewModel(
        ctx.read<ReferenceDocumentRepository>(),
        ctx.read<DraftRepository>(),
      )..load(),
      child: const _DocumentListView(),
    );
  }
}

class _DocumentListView extends StatefulWidget {
  const _DocumentListView();

  @override
  State<_DocumentListView> createState() => _DocumentListViewState();
}

class _DocumentListViewState extends State<_DocumentListView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(ReferenceDocument doc) async {
    final vm = context.read<DocumentListViewModel>();
    if (!doc.isOpen) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
              '${doc.number} sudah selesai dan tidak bisa diproses lagi.'),
        ));
      return;
    }
    await Navigator.of(context)
        .pushNamed(AppRoutes.transactionDetail, arguments: doc.number);
    // Status, progres, dan penanda draf bisa berubah setelah dari detail.
    await vm.load(silent: true);
  }

  void _resetFilters(DocumentListViewModel vm) {
    _search.clear();
    vm.resetFilters();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DocumentListViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Dokumen')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.screen, 0, AppSpace.screen, AppSpace.sm),
            child: Column(
              children: [
                _TypeSegment(type: vm.type, onChanged: vm.setType),
                const SizedBox(height: AppSpace.md),
                TextField(
                  controller: _search,
                  onChanged: vm.setQuery,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Cari nomor dokumen atau '
                        '${vm.type == DocumentType.receiving ? 'vendor' : 'tujuan'}',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: vm.query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Hapus pencarian',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _search.clear();
                              vm.setQuery('');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                _StatusFilterRow(value: vm.filter, onChanged: vm.setFilter),
              ],
            ),
          ),
          Expanded(child: _buildBody(vm)),
        ],
      ),
    );
  }

  Widget _buildBody(DocumentListViewModel vm) {
    final all = vm.allOfType;
    if (vm.loading && all == null) {
      return const LoadingView(message: 'Memuat dokumen...');
    }
    if (vm.error != null && all == null) {
      return ErrorView(message: vm.error!, onRetry: vm.load);
    }
    if (all == null) return const SizedBox.shrink();

    final code = vm.type.code;
    if (all.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => vm.load(silent: true),
        child: ListView(children: [
          const SizedBox(height: AppSpace.xxl),
          EmptyView(
            icon: Icons.inbox_outlined,
            title: 'Belum ada dokumen $code',
            message: vm.type == DocumentType.receiving
                ? 'Purchase Order untuk gudang Anda akan muncul di sini.'
                : 'BON pengeluaran untuk gudang Anda akan muncul di sini.',
          ),
        ]),
      );
    }

    final docs = vm.visible;
    if (docs.isEmpty) {
      return EmptyView(
        icon: Icons.search_off_rounded,
        title: 'Tidak ada dokumen yang cocok',
        message: vm.filter == DocumentStatusFilter.open && vm.query.isEmpty
            ? 'Semua dokumen $code sudah selesai.'
            : 'Coba kata kunci lain atau ubah filter status.',
        actionLabel: 'Tampilkan semua dokumen',
        onAction: () => _resetFilters(vm),
      );
    }

    return RefreshIndicator(
      onRefresh: () => vm.load(silent: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.screen, AppSpace.sm, AppSpace.screen, AppSpace.xl),
        itemCount: docs.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
        itemBuilder: (_, i) => DocumentCard(
          document: docs[i],
          hasDraft: vm.hasDraft(docs[i].number),
          onTap: () => _open(docs[i]),
        ),
      ),
    );
  }
}

class _TypeSegment extends StatelessWidget {
  final DocumentType type;
  final ValueChanged<DocumentType> onChanged;

  const _TypeSegment({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<DocumentType>(
        showSelectedIcon: false,
        segments: [
          for (final t in DocumentType.values)
            ButtonSegment(
              value: t,
              icon: Icon(t == DocumentType.receiving
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded),
              label: Text('${t.code} · ${t.label}'),
            ),
        ],
        selected: {type},
        onSelectionChanged: (s) => onChanged(s.first),
        style: ButtonStyle(
          minimumSize:
              const WidgetStatePropertyAll(Size.fromHeight(AppSize.minTouch)),
          textStyle: const WidgetStatePropertyAll(AppTextStyles.label),
          side: const WidgetStatePropertyAll(
              BorderSide(color: AppColors.border)),
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? DocumentTypeBadge.background(type)
                  : AppColors.surface),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? DocumentTypeBadge.foreground(type)
                  : AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _StatusFilterRow extends StatelessWidget {
  final DocumentStatusFilter value;
  final ValueChanged<DocumentStatusFilter> onChanged;

  const _StatusFilterRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: AppSpace.sm,
        children: [
          for (final f in DocumentStatusFilter.values)
            ChoiceChip(
              label: Text(f.label),
              selected: value == f,
              onSelected: (_) => onChanged(f),
              labelStyle: AppTextStyles.label.copyWith(
                color: value == f ? AppColors.onNavy : AppColors.textPrimary,
              ),
              selectedColor: AppColors.navy,
              backgroundColor: AppColors.surface,
              checkmarkColor: AppColors.onNavy,
              side: const BorderSide(color: AppColors.border),
            ),
        ],
      ),
    );
  }
}
