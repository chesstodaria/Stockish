import 'package:flutter/material.dart';

import '../data/transaction_rules.dart';
import '../models/draft.dart';
import '../models/reference_document.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import 'item_status_chip.dart';

/// Kartu item di Detail Transaksi: target (sisa), jumlah yang sudah
/// diinput, dan status. Angka ditulis besar supaya terbaca dari jarak
/// lengan.
class TransactionItemCard extends StatelessWidget {
  final ReferenceDocumentItem item;
  final DraftLine? line;
  final ItemStatus status;
  final VoidCallback? onTap;

  const TransactionItemCard({
    super.key,
    required this.item,
    required this.line,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fulfilled = status == ItemStatus.fulfilled;
    final unavailable = line?.markedUnavailable ?? false;
    return Card(
      color: fulfilled ? AppColors.surfaceMuted : AppColors.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(item.itemName, style: AppTextStyles.bodyStrong),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  ItemStatusChip(status),
                ],
              ),
              const SizedBox(height: AppSpace.xs),
              Text('${item.itemCode}  •  Rak ${item.rackNumber}',
                  style: AppTextStyles.code),
              if (!fulfilled) ...[
                const SizedBox(height: AppSpace.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _Figure(
                        label: 'Target',
                        value: Fmt.qty(item.remainingQuantity),
                        uom: item.uom,
                      ),
                    ),
                    Expanded(
                      child: unavailable
                          ? const _Figure(
                              label: 'Diinput',
                              value: 'Tidak tersedia',
                              small: true,
                            )
                          : _Figure(
                              label: 'Diinput',
                              value: Fmt.qty(line?.quantity ?? 0),
                              uom: item.uom,
                            ),
                    ),
                    if (onTap != null)
                      const Icon(Icons.edit_outlined,
                          color: AppColors.textSecondary),
                  ],
                ),
              ],
              if (item.processedQuantity > 0 || item.availableStock != null) ...[
                const SizedBox(height: AppSpace.sm),
                Text(
                  [
                    if (item.processedQuantity > 0)
                      'Dokumen ${Fmt.qty(item.orderedQuantity)}, sudah diproses '
                          '${Fmt.qty(item.processedQuantity)}',
                    if (item.availableStock != null)
                      'Stok ${Fmt.qty(item.availableStock!)} ${item.uom}',
                  ].join('  •  '),
                  style: AppTextStyles.bodySecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final String? uom;
  final bool small;

  const _Figure({
    required this.label,
    required this.value,
    this.uom,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodySecondary),
        Text.rich(
          TextSpan(children: [
            TextSpan(
              text: value,
              style: small
                  ? AppTextStyles.bodyStrong
                  : AppTextStyles.quantityLarge,
            ),
            if (uom != null)
              TextSpan(text: ' $uom', style: AppTextStyles.label),
          ]),
        ),
      ],
    );
  }
}
