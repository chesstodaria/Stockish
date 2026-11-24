import 'package:flutter/material.dart';

import '../data/transaction_rules.dart';
import '../models/draft.dart';
import '../models/reference_document.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import 'app_pill.dart';
import 'status_chip.dart';

/// Kartu item di Detail Transaksi: nama, kode, status, target dan jumlah
/// yang sudah diinput.
///
/// Angka diinput ditulis besar dan diberi warna status, sehingga mata
/// langsung menemukan item yang belum lengkap tanpa membaca labelnya.
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
    final (_, accent, _) = StatusChip.styleOf(status);
    final input = unavailable ? null : (line?.quantity ?? 0);

    return Card(
      color: fulfilled ? AppColors.surfaceMuted : AppColors.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg,
            vertical: AppSpace.md + 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child:
                        Text(item.itemName, style: AppTextStyles.bodyStrong),
                  ),
                  if (onTap != null)
                    const Padding(
                      padding: EdgeInsets.only(left: AppSpace.sm),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${item.itemCode}  ·  Rak ${item.rackNumber}  ·  ${item.uom}',
                style: AppTextStyles.code,
              ),
              if (!fulfilled) ...[
                const SizedBox(height: AppSpace.sm + 2),
                Row(
                  children: [
                    StatusChip(status),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: input == null
                              ? AppPill(
                                  label: 'Tidak tersedia',
                                  background: AppColors.pendingBg,
                                  foreground: AppColors.pendingFg,
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      Fmt.qty(input),
                                      style: AppTextStyles.title.copyWith(
                                        color: status == ItemStatus.pending
                                            ? AppColors.textPrimary
                                            : accent,
                                      ),
                                    ),
                                    Text(
                                      ' / ${Fmt.qty(item.remainingQuantity)}',
                                      style: AppTextStyles.code,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (item.processedQuantity > 0 || item.availableStock != null) ...[
                const SizedBox(height: AppSpace.xs + 2),
                Text(
                  [
                    if (item.processedQuantity > 0)
                      'Dokumen ${Fmt.qty(item.orderedQuantity)}, sudah '
                          'diproses ${Fmt.qty(item.processedQuantity)}',
                    if (item.availableStock != null)
                      'Stok ${Fmt.qty(item.availableStock!)} ${item.uom}',
                  ].join('  ·  '),
                  style: AppTextStyles.code,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
