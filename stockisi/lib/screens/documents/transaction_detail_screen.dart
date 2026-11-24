import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/draft_repository.dart';
import '../../data/repositories/reference_document_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repository_exceptions.dart';
import '../../data/transaction_rules.dart';
import '../../models/document_type.dart';
import '../../models/reference_document.dart';
import '../../services/formatters.dart';
import '../../services/scan_launcher.dart';
import '../../services/session_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/transaction_view_model.dart';
import '../../widgets/document_type_badge.dart';
import '../../widgets/primary_action_button.dart';
import '../../widgets/state_views.dart';
import '../../widgets/transaction_item_card.dart';
import '../app_routes.dart';
import 'transaction_sheets.dart';

/// Detail Transaksi (layar 5): input barang lewat scan atau manual.
class TransactionDetailScreen extends StatelessWidget {
  final String documentNumber;

  const TransactionDetailScreen({super.key, required this.documentNumber});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => TransactionViewModel(
        documentNumber: documentNumber,
        warehouseCode:
            ctx.read<SessionController>().operator?.warehouseCode ?? '',
        documents: ctx.read<ReferenceDocumentRepository>(),
        drafts: ctx.read<DraftRepository>(),
        transactions: ctx.read<TransactionRepository>(),
      ),
      child: const _DetailView(),
    );
  }
}

enum _LeaveChoice { save, discard }

class _DetailView extends StatefulWidget {
  const _DetailView();

  @override
  State<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<_DetailView> {
  late final TransactionViewModel _vm = context.read<TransactionViewModel>();
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _vm.load();
    if (!mounted) return;
    switch (_vm.state) {
      case TransactionLoadState.staleDraft:
        await _showExitNotice(
          'Dokumen sudah berubah',
          'Dokumen ${_vm.documentNumber} sudah diproses operator lain sejak '
              'draf Anda disimpan, jadi sisa barangnya berubah. Draf Anda '
              'dibuang. Buka lagi dokumennya untuk mulai dengan sisa terbaru.',
        );
      case TransactionLoadState.alreadySubmitted:
        await _showExitNotice(
          'Dokumen sudah selesai',
          'Dokumen ${_vm.documentNumber} sudah diselesaikan operator lain dan '
              'tidak bisa diproses lagi. Draf untuk dokumen ini, kalau ada, '
              'dibuang.',
        );
      case TransactionLoadState.ready:
        if (_vm.resumedFromDraft) {
          _snack('Melanjutkan draf ${_vm.documentNumber}.');
        }
      default:
        break;
    }
  }

  Future<void> _showExitNotice(String title, String message) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kembali ke daftar'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------------------------------------- input

  Future<void> _scan() async {
    final outcome = await context.read<ScanLauncher>()(context);
    if (!mounted || outcome == null) return;
    switch (outcome) {
      case ScannedCode(:final raw):
        await _handleScan(raw);
      case ManualInputRequested():
        await _manual();
      case CameraUnavailable():
        await _manual(notice: outcome.message);
    }
  }

  Future<void> _handleScan(String raw) async {
    final lookup = _vm.lookupScan(raw);
    final item = lookup.item;
    if (item == null) {
      final next = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Scan ditolak'),
          content: Text(lookup.error!),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('manual'),
              child: const Text('Input manual'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop('scan'),
              child: const Text('Scan lagi'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (next == 'scan') await _scan();
      if (next == 'manual') await _manual();
      return;
    }
    final added = await showAddQuantitySheet(context, _vm, item);
    if (added != null) _confirmAdded(item, added);
  }

  Future<void> _manual({String? notice}) async {
    final result = await showManualInputSheet(context, _vm, notice: notice);
    if (result != null) _confirmAdded(result.$1, result.$2);
  }

  void _confirmAdded(ReferenceDocumentItem item, int qty) {
    final total = _vm.lineOf(item.itemCode)?.quantity ?? qty;
    _snack('+${Fmt.qty(qty)} ${item.uom} ${item.itemName}. '
        'Total ${Fmt.qty(total)}/${Fmt.qty(item.remainingQuantity)}.');
  }

  Future<void> _openItem(ReferenceDocumentItem item) async {
    final action = await showItemActionsSheet(context, _vm, item);
    if (action == null) return;
    _snack(switch (action) {
      ItemAction.quantitySet => 'Jumlah ${item.itemName} diubah.',
      ItemAction.cleared => 'Input ${item.itemName} dihapus. Status Pending.',
      ItemAction.markedUnavailable =>
        '${item.itemName} ditandai tidak tersedia.',
      ItemAction.unmarked =>
        'Tanda tidak tersedia dibatalkan. ${item.itemName} kembali Pending.',
    });
  }

  void _openSummary() {
    Navigator.of(context)
        .pushNamed(AppRoutes.transactionSummary, arguments: _vm);
  }

  // ------------------------------------------------------- tombol kembali

  Future<void> _onBlockedPop() async {
    if (_leaving) return;
    final choice = await showDialog<_LeaveChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari dokumen?'),
        content: Text(
          'Input untuk ${_vm.documentNumber} belum disubmit. Simpan sebagai '
          'draf supaya bisa dilanjutkan nanti?',
        ),
        actionsOverflowDirection: VerticalDirection.up,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(_LeaveChoice.discard),
            child: const Text('Buang draf'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: const Size(AppSize.minTouch * 2, AppSize.minTouch)),
            onPressed: () => Navigator.of(ctx).pop(_LeaveChoice.save),
            child: const Text('Simpan draf'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    _leaving = true;
    try {
      if (choice == _LeaveChoice.save) {
        await _vm.saveDraft();
      } else {
        await _vm.discardDraft();
      }
      if (mounted) Navigator.of(context).pop();
    } on RepositoryException catch (e) {
      _leaving = false;
      if (mounted) _snack('Draf gagal diproses. ${e.message}');
    }
  }

  // --------------------------------------------------------------- tampilan

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TransactionViewModel>();
    final ready = vm.state == TransactionLoadState.ready;
    return PopScope(
      canPop: !vm.isDirty || _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBlockedPop();
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 64,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      vm.documentNumber,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (ready) ...[
                    const SizedBox(width: AppSpace.sm),
                    DocumentTypeBadge(vm.document.type),
                  ],
                ],
              ),
              if (ready)
                Text(
                  vm.document.counterparty,
                  style: AppTextStyles.code,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        body: switch (vm.state) {
          TransactionLoadState.loading =>
            const LoadingView(message: 'Memuat dokumen...'),
          TransactionLoadState.error =>
            ErrorView(message: vm.loadError ?? '', onRetry: _load),
          TransactionLoadState.notFound => EmptyView(
              icon: Icons.find_in_page_outlined,
              title: 'Dokumen tidak ditemukan',
              message: 'Dokumen ${vm.documentNumber} tidak ada di gudang Anda.',
              actionLabel: 'Kembali ke daftar',
              onAction: () => Navigator.of(context).pop(),
            ),
          TransactionLoadState.ready => _ReadyBody(onOpenItem: _openItem),
          _ => const SizedBox.shrink(),
        },
        bottomNavigationBar: ready
            ? _BottomActions(
                onScan: _scan,
                onManual: () => _manual(),
                onSummary: _openSummary,
              )
            : null,
      ),
    );
  }
}

class _ReadyBody extends StatelessWidget {
  final ValueChanged<ReferenceDocumentItem> onOpenItem;
  const _ReadyBody({required this.onOpenItem});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TransactionViewModel>();
    final doc = vm.document;
    final items = [...vm.processableItems, ...doc.items.where((i) => i.isFulfilled)];
    return Column(
      children: [
        _ProgressHeader(vm: vm),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.screen, AppSpace.md, AppSpace.screen, AppSpace.xl),
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Text(
                  '${doc.type == DocumentType.receiving ? 'Vendor' : 'Tujuan'}: '
                  '${doc.counterparty}  •  '
                  '${Fmt.date(doc.documentDate)}',
                  style: AppTextStyles.bodySecondary,
                );
              }
              final item = items[i - 1];
              final status = vm.statusOf(item);
              return TransactionItemCard(
                item: item,
                line: vm.lineOf(item.itemCode),
                status: status,
                onTap: status == ItemStatus.fulfilled
                    ? null
                    : () => onOpenItem(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Progres yang menempel di atas daftar item.
class _ProgressHeader extends StatelessWidget {
  final TransactionViewModel vm;
  const _ProgressHeader({required this.vm});

  @override
  Widget build(BuildContext context) {
    final total = vm.processableItems.length;
    final checked = vm.checkedCount;
    final fulfilled = vm.countOf(ItemStatus.fulfilled);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpace.screen, AppSpace.sm, AppSpace.screen, AppSpace.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$checked dari $total', style: AppTextStyles.quantity),
              const SizedBox(width: AppSpace.sm),
              const Expanded(
                child: Text('item diperiksa', style: AppTextStyles.bodySecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: total == 0 ? 1 : checked / total,
              minHeight: 8,
              backgroundColor: AppColors.pendingBg,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            [
              'Belum ${vm.countOf(ItemStatus.pending)}',
              'Parsial ${vm.countOf(ItemStatus.partial)}',
              'Selesai ${vm.countOf(ItemStatus.complete)}',
              if (fulfilled > 0) 'Sudah terpenuhi $fulfilled',
            ].join('  •  '),
            style: AppTextStyles.bodySecondary,
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onManual;
  final VoidCallback onSummary;

  const _BottomActions({
    required this.onScan,
    required this.onManual,
    required this.onSummary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.screen, AppSpace.md, AppSpace.screen, AppSpace.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PrimaryActionButton(
                label: 'Scan QR',
                icon: Icons.qr_code_scanner_rounded,
                onPressed: onScan,
              ),
              const SizedBox(height: AppSpace.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onManual,
                      icon: const Icon(Icons.keyboard_rounded),
                      label: const Text('Input manual'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSummary,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Ringkasan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
