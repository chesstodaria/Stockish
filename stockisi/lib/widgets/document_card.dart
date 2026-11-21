import 'package:flutter/material.dart';

import '../models/reference_document.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

/// Kartu dokumen di tab Dokumen. Dokumen SUBMITTED tampil redup dengan
/// label "Selesai" dan tanpa panah, karena tidak bisa dibuka lagi.
class DocumentCard extends StatelessWidget {
  final ReferenceDocument document;
  final bool hasDraft;
  final VoidCallback onTap;

  const DocumentCard({
    super.key,
    required this.document,
    required this.hasDraft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final d = document;
    final open = d.isOpen;
    return Card(
      color: open ? AppColors.surface : AppColors.surfaceMuted,
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
                  Expanded(
                    child: Text(
                      d.number,
                      style: AppTextStyles.title.copyWith(
                        color: open
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (open)
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary)
                  else
                    const _Tag(
                      icon: Icons.task_alt_rounded,
                      label: 'Selesai',
                      bg: AppColors.surface,
                      fg: AppColors.textSecondary,
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.xs),
              Text(d.counterparty, style: AppTextStyles.bodySecondary),
              const SizedBox(height: AppSpace.xs),
              Text(
                '${Fmt.date(d.documentDate)}  •  ${d.itemCount} item',
                style: AppTextStyles.code,
              ),
              if (d.hasPartialProgress) ...[
                const SizedBox(height: AppSpace.md),
                _PartialProgress(document: d),
              ],
              if (hasDraft && open) ...[
                const SizedBox(height: AppSpace.md),
                const _Tag(
                  icon: Icons.edit_note_rounded,
                  label: 'Ada draf',
                  bg: AppColors.partialBg,
                  fg: AppColors.partialFg,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PartialProgress extends StatelessWidget {
  final ReferenceDocument document;
  const _PartialProgress({required this.document});

  @override
  Widget build(BuildContext context) {
    final done = document.fulfilledItemCount;
    final total = document.itemCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Partial: $done dari $total item terpenuhi',
          style: AppTextStyles.label,
        ),
        const SizedBox(height: AppSpace.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : done / total,
            minHeight: 6,
            backgroundColor: AppColors.pendingBg,
            color: AppColors.navy,
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;

  const _Tag({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm, vertical: AppSpace.xs),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: AppSpace.xs),
          Text(label, style: AppTextStyles.chip.copyWith(color: fg)),
        ],
      ),
    );
  }
}
