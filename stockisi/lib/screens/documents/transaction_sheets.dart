import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/reference_document.dart';
import '../../services/formatters.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/transaction_view_model.dart';
import '../../widgets/inline_error_banner.dart';
import '../../widgets/item_status_chip.dart';
import '../../widgets/primary_action_button.dart';

Future<T?> _showSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: AppSpace.xl,
        right: AppSpace.xl,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpace.xl,
      ),
      child: SingleChildScrollView(child: child),
    ),
  );
}

String _verb(TransactionViewModel vm) => vm.isReceiving ? 'diterima' : 'dikeluarkan';

/// Kolom angka besar untuk kuantitas.
class _QuantityField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String uom;
  final String? errorText;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  const _QuantityField({
    required this.controller,
    required this.label,
    required this.uom,
    this.errorText,
    this.autofocus = false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textInputAction: TextInputAction.done,
      style: AppTextStyles.quantity,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        suffixText: uom,
        suffixStyle: AppTextStyles.label,
        errorText: errorText,
        errorMaxLines: 3,
      ),
    );
  }
}

class _ItemHeader extends StatelessWidget {
  final ReferenceDocumentItem item;
  final TransactionViewModel vm;
  const _ItemHeader({required this.item, required this.vm});

  @override
  Widget build(BuildContext context) {
    final line = vm.lineOf(item.itemCode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(item.itemName, style: AppTextStyles.title)),
            const SizedBox(width: AppSpace.sm),
            ItemStatusChip(vm.statusOf(item)),
          ],
        ),
        const SizedBox(height: AppSpace.xs),
        Text('${item.itemCode}  •  Rak ${item.rackNumber}',
            style: AppTextStyles.code),
        const SizedBox(height: AppSpace.sm),
        Text(
          [
            'Target ${Fmt.qty(item.remainingQuantity)} ${item.uom}',
            if (line?.markedUnavailable ?? false)
              'Ditandai tidak tersedia'
            else
              'Diinput ${Fmt.qty(line?.quantity ?? 0)} ${item.uom}',
            if (item.availableStock != null)
              'Stok ${Fmt.qty(item.availableStock!)} ${item.uom}',
          ].join('  •  '),
          style: AppTextStyles.bodySecondary,
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ tambah jumlah

/// Setelah scan berhasil: isi jumlah yang ditambahkan. Mengembalikan
/// jumlah yang ditambahkan, atau null kalau batal.
Future<int?> showAddQuantitySheet(
  BuildContext context,
  TransactionViewModel vm,
  ReferenceDocumentItem item,
) {
  return _showSheet<int>(context, _AddQuantitySheet(vm: vm, item: item));
}

class _AddQuantitySheet extends StatefulWidget {
  final TransactionViewModel vm;
  final ReferenceDocumentItem item;
  const _AddQuantitySheet({required this.vm, required this.item});

  @override
  State<_AddQuantitySheet> createState() => _AddQuantitySheetState();
}

class _AddQuantitySheetState extends State<_AddQuantitySheet> {
  late final TextEditingController _qty;
  String? _error;

  @override
  void initState() {
    super.initState();
    final line = widget.vm.lineOf(widget.item.itemCode);
    final current =
        (line == null || line.markedUnavailable) ? 0 : line.quantity;
    final suggestion = widget.item.remainingQuantity - current;
    _qty = TextEditingController(text: suggestion > 0 ? '$suggestion' : '');
    _qty.selection =
        TextSelection(baseOffset: 0, extentOffset: _qty.text.length);
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  void _submit() {
    final qty = int.tryParse(_qty.text) ?? 0;
    final error = widget.vm.addQuantity(widget.item, qty);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(qty);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ItemHeader(item: widget.item, vm: widget.vm),
        const SizedBox(height: AppSpace.xl),
        _QuantityField(
          controller: _qty,
          autofocus: true,
          label: 'Jumlah ${_verb(widget.vm)} (ditambahkan)',
          uom: widget.item.uom,
          errorText: _error,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpace.xl),
        PrimaryActionButton(
          label: 'Tambah',
          icon: Icons.add_rounded,
          onPressed: _submit,
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ input manual

/// Input manual: kode barang dan kuantitas (menambah). [notice] menjelaskan
/// kenapa operator diarahkan ke sini (misalnya kamera ditolak).
/// Mengembalikan (item, jumlah) yang ditambahkan.
Future<(ReferenceDocumentItem, int)?> showManualInputSheet(
  BuildContext context,
  TransactionViewModel vm, {
  String? notice,
}) {
  return _showSheet<(ReferenceDocumentItem, int)>(
      context, _ManualInputSheet(vm: vm, notice: notice));
}

class _ManualInputSheet extends StatefulWidget {
  final TransactionViewModel vm;
  final String? notice;
  const _ManualInputSheet({required this.vm, this.notice});

  @override
  State<_ManualInputSheet> createState() => _ManualInputSheetState();
}

class _ManualInputSheetState extends State<_ManualInputSheet> {
  final _code = TextEditingController();
  final _qty = TextEditingController();
  String? _codeError;
  String? _qtyError;
  ReferenceDocumentItem? _match;

  @override
  void dispose() {
    _code.dispose();
    _qty.dispose();
    super.dispose();
  }

  void _onCodeChanged(String value) {
    final lookup = widget.vm.lookupManual(value);
    setState(() {
      _codeError = null;
      _match = lookup.item;
    });
  }

  void _submit() {
    final lookup = widget.vm.lookupManual(_code.text);
    final item = lookup.item;
    if (item == null) {
      setState(() => _codeError = lookup.error);
      return;
    }
    final qty = int.tryParse(_qty.text) ?? 0;
    final error = widget.vm.addQuantity(item, qty);
    if (error != null) {
      setState(() {
        _codeError = null;
        _qtyError = error;
      });
      return;
    }
    Navigator.of(context).pop((item, qty));
  }

  @override
  Widget build(BuildContext context) {
    final match = _match;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Input manual', style: AppTextStyles.title),
        const SizedBox(height: AppSpace.xs),
        const Text(
          'Ketik kode barang dari label, lalu jumlah yang ditambahkan.',
          style: AppTextStyles.bodySecondary,
        ),
        if (widget.notice != null) ...[
          const SizedBox(height: AppSpace.lg),
          InlineErrorBanner(widget.notice!),
        ],
        const SizedBox(height: AppSpace.xl),
        TextField(
          controller: _code,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          style: AppTextStyles.body,
          onChanged: _onCodeChanged,
          decoration: InputDecoration(
            labelText: 'Kode barang',
            hintText: 'Contoh: BRG-0001',
            prefixIcon: const Icon(Icons.qr_code_2_rounded),
            errorText: _codeError,
            errorMaxLines: 3,
            helperMaxLines: 2,
            helperText: match == null
                ? null
                : '${match.itemName} • target ${Fmt.qty(match.remainingQuantity)} ${match.uom}',
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        _QuantityField(
          controller: _qty,
          label: 'Jumlah ${_verb(widget.vm)} (ditambahkan)',
          uom: match?.uom ?? '',
          errorText: _qtyError,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpace.xl),
        PrimaryActionButton(
          label: 'Tambah',
          icon: Icons.add_rounded,
          onPressed: _submit,
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- aksi item

/// Hasil aksi di sheet item, untuk pesan konfirmasi di layar.
enum ItemAction { quantitySet, cleared, markedUnavailable, unmarked }

/// Sheet dari kartu item: ubah jumlah (mengganti), hapus input, tandai
/// atau batalkan "Tidak tersedia".
Future<ItemAction?> showItemActionsSheet(
  BuildContext context,
  TransactionViewModel vm,
  ReferenceDocumentItem item,
) {
  return _showSheet<ItemAction>(context, _ItemActionsSheet(vm: vm, item: item));
}

class _ItemActionsSheet extends StatefulWidget {
  final TransactionViewModel vm;
  final ReferenceDocumentItem item;
  const _ItemActionsSheet({required this.vm, required this.item});

  @override
  State<_ItemActionsSheet> createState() => _ItemActionsSheetState();
}

class _ItemActionsSheetState extends State<_ItemActionsSheet> {
  late final TextEditingController _qty;
  String? _error;

  @override
  void initState() {
    super.initState();
    final line = widget.vm.lineOf(widget.item.itemCode);
    _qty = TextEditingController(
      text: (line == null || line.markedUnavailable) ? '' : '${line.quantity}',
    );
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  void _save() {
    final error =
        widget.vm.setQuantity(widget.item, int.tryParse(_qty.text) ?? 0);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(ItemAction.quantitySet);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final item = widget.item;
    final line = vm.lineOf(item.itemCode);
    final unavailable = line?.markedUnavailable ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ItemHeader(item: item, vm: vm),
        const SizedBox(height: AppSpace.xl),
        if (unavailable) ...[
          Text(
            vm.isReceiving
                ? 'Item ini ditandai tidak tersedia: barang tidak datang. '
                    'Statusnya Partial dengan jumlah 0.'
                : 'Item ini ditandai tidak tersedia: barang tidak bisa '
                    'diambil. Statusnya Partial dengan jumlah 0.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpace.xl),
          SizedBox(
            height: AppSize.primaryButton,
            child: OutlinedButton.icon(
              onPressed: () {
                vm.clearItem(item);
                Navigator.of(context).pop(ItemAction.unmarked);
              },
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Batalkan tanda Tidak tersedia'),
            ),
          ),
        ] else ...[
          _QuantityField(
            controller: _qty,
            label: 'Jumlah ${_verb(vm)} (mengganti)',
            uom: item.uom,
            errorText: _error,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: AppSpace.lg),
          PrimaryActionButton(
            label: 'Simpan jumlah',
            icon: Icons.check_rounded,
            onPressed: _save,
          ),
          const SizedBox(height: AppSpace.md),
          if (line != null)
            SizedBox(
              height: AppSize.minTouch,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: () {
                  vm.clearItem(item);
                  Navigator.of(context).pop(ItemAction.cleared);
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Hapus input'),
              ),
            )
          else ...[
            const Divider(),
            const SizedBox(height: AppSpace.sm),
            Text(
              vm.isReceiving
                  ? 'Barang ini sama sekali tidak datang?'
                  : 'Barang ini tidak bisa diambil sama sekali?',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: AppSpace.sm),
            SizedBox(
              height: AppSize.minTouch,
              child: OutlinedButton.icon(
                onPressed: () {
                  vm.markUnavailable(item);
                  Navigator.of(context).pop(ItemAction.markedUnavailable);
                },
                icon: const Icon(Icons.block_rounded),
                label: const Text('Tandai tidak tersedia'),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
