import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/transaction_repository.dart';
import '../../data/repository_exceptions.dart';
import '../../data/transaction_rules.dart';
import '../../models/document_type.dart';
import '../../models/reference_document.dart';
import '../../models/transaction_record.dart';
import '../../services/formatters.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/transaction_view_model.dart';
import '../../widgets/document_type_badge.dart';
import '../../widgets/inline_error_banner.dart';
import '../../widgets/item_status_chip.dart';
import '../../widgets/primary_action_button.dart';
import '../app_routes.dart';

/// Ringkasan Transaksi (layar 6) dan dialog Konfirmasi Submit (layar 7).
///
/// Diadaptasi dari `stockish/lib/screens/transaction_summary_screen.dart`:
/// dialog Partial (Batal / Simpan sebagai Partial / Tandai Selesai), guard
/// submit ganda, dialog berhasil yang tidak bisa ditutup sembarangan dan
/// langsung kembali ke daftar. Berbeda dari kode lama, INT juga mendapat
/// pilihan Partial (CONTEXT 6).
class TransactionSummaryScreen extends StatelessWidget {
  final TransactionViewModel viewModel;

  const TransactionSummaryScreen({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: viewModel,
      child: const _SummaryView(),
    );
  }
}

enum _Choice { keepOpen, close }

class _SummaryView extends StatefulWidget {
  const _SummaryView();

  @override
  State<_SummaryView> createState() => _SummaryViewState();
}

class _SummaryViewState extends State<_SummaryView> {
  late final TransactionViewModel _vm = context.read<TransactionViewModel>();
  late final _deliveryNo = TextEditingController(text: _vm.vendorDeliveryNo);
  final _deliveryFocus = FocusNode();
  final _scroll = ScrollController();
  String? _deliveryError;
  String? _banner;

  @override
  void dispose() {
    _deliveryNo.dispose();
    _deliveryFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _showBanner(String message) {
    setState(() => _banner = message);
    _scroll.animateTo(0,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _submit() async {
    if (_vm.submitting) return;
    setState(() {
      _banner = null;
      _deliveryError = null;
    });

    final check = _vm.checkBeforeSubmit();
    if (check != null) {
      if (check.problem == SubmitProblem.missingDeliveryNo) {
        setState(() => _deliveryError = check.message);
        _deliveryFocus.requestFocus();
      } else {
        _showBanner(check.message);
      }
      return;
    }

    final choice = await _confirm();
    if (choice == null || !mounted) return;

    try {
      final record = await _vm.submit(
          choice == _Choice.keepOpen ? SubmitMode.keepOpen : SubmitMode.close);
      if (!mounted) return;
      await _showSuccess(record);
    } on SubmitException catch (e) {
      if (!mounted) return;
      if (e.failure == SubmitFailure.rulesNotMet) {
        _showBanner(e.message);
      } else {
        await _showProcessedElsewhere(e.message);
      }
    } on RepositoryException catch (e) {
      if (!mounted) return;
      _showBanner('Submit gagal. ${e.message} Input Anda tetap ada di layar '
          'ini, tekan Submit lagi untuk mencoba.');
    }
  }

  /// Konfirmasi Submit. Kalau ada item Partial, operator memilih Simpan
  /// sebagai Partial atau Tandai Selesai.
  Future<_Choice?> _confirm() {
    final partial = _vm.partialCount;
    final doc = _vm.document;
    final effect = _vm.isReceiving
        ? 'Stok akan bertambah sesuai jumlah yang diterima.'
        : 'Stok akan berkurang sesuai jumlah yang dikeluarkan.';
    return showDialog<_Choice>(
      context: context,
      builder: (ctx) {
        if (partial == 0) {
          return AlertDialog(
            title: const Text('Submit transaksi?'),
            content: Text('$effect Transaksi ${doc.number} tidak bisa diubah '
                'setelah disubmit.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Batal'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize:
                        const Size(AppSize.minTouch * 2, AppSize.minTouch)),
                onPressed: () => Navigator.of(ctx).pop(_Choice.close),
                child: const Text('Submit'),
              ),
            ],
          );
        }
        return AlertDialog(
          title: Text('Ada $partial item Partial'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jumlah $partial item kurang dari target. Pilih cara '
                  'menyimpan transaksi ini:',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: AppSpace.md),
                const _ChoiceExplain(
                  title: 'Simpan sebagai Partial',
                  body: 'Dokumen tetap terbuka. Sisa barang bisa diproses '
                      'di transaksi berikutnya.',
                ),
                const SizedBox(height: AppSpace.sm),
                const _ChoiceExplain(
                  title: 'Tandai Selesai',
                  body: 'Dokumen ditutup walaupun ada kekurangan. Sisa '
                      'barang tidak bisa diproses lagi.',
                ),
                const SizedBox(height: AppSpace.md),
                Text(effect, style: AppTextStyles.bodySecondary),
              ],
            ),
          ),
          actionsOverflowDirection: VerticalDirection.up,
          actionsOverflowButtonSpacing: AppSpace.sm,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(_Choice.keepOpen),
              child: const Text('Simpan sebagai Partial'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize:
                      const Size(AppSize.minTouch * 2, AppSize.minTouch)),
              onPressed: () => Navigator.of(ctx).pop(_Choice.close),
              child: const Text('Tandai Selesai'),
            ),
          ],
        );
      },
    );
  }

  void _backToList() => Navigator.of(context)
      .popUntil(ModalRoute.withName(AppRoutes.home));

  Future<void> _showSuccess(TransactionRecord record) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          icon: const Icon(Icons.check_circle_rounded,
              color: AppColors.completeFg, size: AppSize.iconLg),
          title: const Text('Transaksi berhasil disubmit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nomor transaksi', style: AppTextStyles.bodySecondary),
              const SizedBox(height: AppSpace.xs),
              SelectableText(record.number, style: AppTextStyles.title),
              const SizedBox(height: AppSpace.lg),
              Text(
                record.closedDocument
                    ? 'Dokumen ${record.documentNumber} selesai.'
                    : 'Dokumen ${record.documentNumber} tetap terbuka untuk '
                        'sisa barang.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Kembali ke daftar dokumen'),
              ),
            ),
          ],
        ),
      ),
    );
    if (mounted) _backToList();
  }

  Future<void> _showProcessedElsewhere(String message) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Dokumen sudah diproses operator lain'),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Kembali ke daftar dokumen'),
            ),
          ],
        ),
      ),
    );
    if (mounted) _backToList();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TransactionViewModel>();
    final doc = vm.document;
    final pending = vm.countOf(ItemStatus.pending);
    final fulfilled = vm.countOf(ItemStatus.fulfilled);
    return PopScope(
      canPop: !vm.submitting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Ringkasan Transaksi')),
        body: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(
              AppSpace.screen, AppSpace.sm, AppSpace.screen, AppSpace.xl),
          children: [
            _DocumentHeader(document: doc),
            const SizedBox(height: AppSpace.lg),
            _Counts(vm: vm),
            if (_banner != null) ...[
              const SizedBox(height: AppSpace.lg),
              InlineErrorBanner(_banner!),
            ] else if (pending > 0) ...[
              const SizedBox(height: AppSpace.lg),
              InlineErrorBanner('Masih ada $pending item Pending. Kembali ke '
                  'detail untuk memeriksanya, atau tandai tidak tersedia.'),
            ],
            if (vm.isReceiving) ...[
              const SizedBox(height: AppSpace.xl),
              TextField(
                controller: _deliveryNo,
                focusNode: _deliveryFocus,
                enabled: !vm.submitting,
                textCapitalization: TextCapitalization.characters,
                style: AppTextStyles.body,
                onChanged: (v) {
                  vm.vendorDeliveryNo = v;
                  if (_deliveryError != null) {
                    setState(() => _deliveryError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Nomor surat jalan vendor',
                  hintText: 'Sesuai dokumen dari sopir vendor',
                  prefixIcon: const Icon(Icons.local_shipping_outlined),
                  errorText: _deliveryError,
                ),
              ),
            ],
            const SizedBox(height: AppSpace.xl),
            const Text('Rekap item', style: AppTextStyles.title),
            const SizedBox(height: AppSpace.sm),
            Card(
              child: Column(
                children: [
                  for (final (i, item) in vm.processableItems.indexed) ...[
                    if (i > 0) const Divider(indent: AppSpace.lg),
                    _ItemRow(
                      item: item,
                      status: vm.statusOf(item),
                      quantity: vm.lineOf(item.itemCode)?.quantity ?? 0,
                      unavailable:
                          vm.lineOf(item.itemCode)?.markedUnavailable ?? false,
                    ),
                  ],
                ],
              ),
            ),
            if (fulfilled > 0) ...[
              const SizedBox(height: AppSpace.sm),
              Text(
                '$fulfilled item sudah terpenuhi di transaksi sebelumnya dan '
                'tidak ikut transaksi ini.',
                style: AppTextStyles.bodySecondary,
              ),
            ],
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.screen),
              child: PrimaryActionButton(
                label: 'Submit',
                icon: Icons.send_rounded,
                loading: vm.submitting,
                onPressed: _submit,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceExplain extends StatelessWidget {
  final String title;
  final String body;
  const _ChoiceExplain({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.bodyStrong),
        Text(body, style: AppTextStyles.bodySecondary),
      ],
    );
  }
}

class _DocumentHeader extends StatelessWidget {
  final ReferenceDocument document;
  const _DocumentHeader({required this.document});

  @override
  Widget build(BuildContext context) {
    final d = document;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: DocumentTypeBadge.background(d.type),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                d.type == DocumentType.receiving
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
                color: DocumentTypeBadge.foreground(d.type),
                size: AppSize.iconSm,
              ),
              const SizedBox(width: AppSpace.xs),
              Text(
                d.type.label,
                style: AppTextStyles.chip
                    .copyWith(color: DocumentTypeBadge.foreground(d.type)),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(d.number,
              style: AppTextStyles.headline
                  .copyWith(color: DocumentTypeBadge.foreground(d.type))),
          const SizedBox(height: AppSpace.xs),
          Text('${d.counterparty}  •  ${Fmt.date(d.documentDate)}',
              style: AppTextStyles.label
                  .copyWith(color: DocumentTypeBadge.foreground(d.type))),
        ],
      ),
    );
  }
}

class _Counts extends StatelessWidget {
  final TransactionViewModel vm;
  const _Counts({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.sm,
      children: [
        for (final s in [
          ItemStatus.complete,
          ItemStatus.partial,
          ItemStatus.pending,
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ItemStatusChip(s),
              const SizedBox(width: AppSpace.xs),
              Text('${vm.countOf(s)}', style: AppTextStyles.bodyStrong),
              const SizedBox(width: AppSpace.sm),
            ],
          ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final ReferenceDocumentItem item;
  final ItemStatus status;
  final int quantity;
  final bool unavailable;

  const _ItemRow({
    required this.item,
    required this.status,
    required this.quantity,
    required this.unavailable,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName, style: AppTextStyles.bodyStrong),
                Text('${item.itemCode}  •  Rak ${item.rackNumber}',
                    style: AppTextStyles.code),
                const SizedBox(height: AppSpace.sm),
                ItemStatusChip(status),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (unavailable)
                const Text('Tidak tersedia', style: AppTextStyles.bodyStrong)
              else
                Text.rich(TextSpan(children: [
                  TextSpan(text: Fmt.qty(quantity), style: AppTextStyles.quantity),
                  TextSpan(
                      text: ' / ${Fmt.qty(item.remainingQuantity)}',
                      style: AppTextStyles.bodySecondary),
                ])),
              Text(item.uom, style: AppTextStyles.label),
            ],
          ),
        ],
      ),
    );
  }
}
