import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/draft_repository.dart';
import '../../data/repositories/reference_document_repository.dart';
import '../../models/document_type.dart';
import '../../models/reference_document.dart';
import '../../theme/app_dimens.dart';
import '../../viewmodels/document_list_view_model.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/app_segmented.dart';
import '../../widgets/document_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/state_views.dart';
import '../app_routes.dart';

/// Tab Dokumen: Daftar Dokumen Referensi (layar 4).
///
/// Hanya dua kontrol di atas daftar, yaitu segmen RCV/INT dan kolom
/// pencarian. Filter status tidak lagi berupa chip terpisah; sebagai
/// gantinya dokumen dikelompokkan menjadi "Perlu diproses" dan "Selesai",
/// sehingga operator langsung tahu mana yang harus dikerjakan.
class DocumentListScreen extends StatelessWidget {
  const DocumentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => DocumentListViewModel(
        ctx.read<ReferenceDocumentRepository>(),
        ctx.read<DraftRepository>(),
      )
        ..setFilter(DocumentStatusFilter.all)
        ..load(),
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
    await vm.load(silent: true);
  }

  void _reset(DocumentListViewModel vm) {
    _search.clear();
    vm.resetFilters();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DocumentListViewModel>();
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.screen, AppSpace.md, AppSpace.screen, 0),
            child: Column(
              children: [
                const AppHeader(title: 'Dokumen'),
                const SizedBox(height: AppSpace.lg),
                AppSearchField(
                  controller: _search,
                  hint: 'Cari nomor dokumen atau '
                      '${vm.type == DocumentType.receiving ? 'vendor' : 'tujuan'}',
                  onChanged: vm.setQuery,
                  showClear: vm.query.isNotEmpty,
                  onClear: () {
                    _search.clear();
                    vm.setQuery('');
                  },
                ),
                const SizedBox(height: AppSpace.md),
                AppSegmented<DocumentType>(
                  value: vm.type,
                  onChanged: vm.setType,
                  segments: [
                    for (final t in DocumentType.values)
                      AppSegment(t, '${t.code} · ${t.label}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
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
      return ErrorView(
        message: vm.error!,
        title: 'Gagal memuat dokumen',
        onRetry: vm.load,
      );
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
        message: 'Coba kata kunci lain.',
        actionLabel: 'Hapus pencarian',
        onAction: () => _reset(vm),
      );
    }

    final open = docs.where((d) => d.isOpen).toList();
    final done = docs.where((d) => !d.isOpen).toList();

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
          if (open.isNotEmpty) ...[
            SectionHeader('Perlu diproses', trailing: '${open.length}'),
            const SizedBox(height: AppSpace.sm),
            for (var i = 0; i < open.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpace.sm + 2),
              DocumentCard(
                document: open[i],
                hasDraft: vm.hasDraft(open[i].number),
                onTap: () => _open(open[i]),
              ),
            ],
          ],
          if (done.isNotEmpty) ...[
            if (open.isNotEmpty) const SizedBox(height: AppSpace.xl),
            SectionHeader('Selesai', trailing: '${done.length}'),
            const SizedBox(height: AppSpace.sm),
            for (var i = 0; i < done.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpace.sm + 2),
              DocumentCard(
                document: done[i],
                hasDraft: false,
                onTap: () => _open(done[i]),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
