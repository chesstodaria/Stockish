import 'package:flutter/material.dart';

import '../models/reference_document.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import '../theme/motion.dart';
import 'app_pill.dart';
import 'pressable.dart';
import 'type_pill.dart';

/// Kartu dokumen di tab Dokumen.
///
/// Dua bobot, bukan satu: dokumen OPEN yang masih perlu dikerjakan tampil
/// penuh dengan garis aksen kiri berwarna sesuai jenisnya (mint untuk
/// Receiving, peach untuk Intransit). Dokumen SUBMITTED tampil redup tanpa
/// garis dan tanpa panah, karena memang tidak bisa dibuka lagi.
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
    final accent = TypePill.foreground(d.type);

    return Pressable(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: open ? AppColors.surface : AppColors.surfaceMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg - 2),
          side: open
              ? const BorderSide(color: AppColors.border)
              : BorderSide.none,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (open) Container(width: 4, color: accent),
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
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: AppColors.textSecondary,
                            )
                          else
                            Text('Selesai', style: AppTextStyles.code),
                        ],
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(d.counterparty,
                          style: AppTextStyles.bodySecondary),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        '${d.type.code}  ·  ${Fmt.date(d.documentDate)}  ·  '
                        '${d.itemCount} item',
                        style: AppTextStyles.code.copyWith(color: accent),
                      ),
                      if (d.hasPartialProgress) ...[
                        const SizedBox(height: AppSpace.sm + 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${d.fulfilledItemCount} dari ${d.itemCount} '
                                'item terpenuhi',
                                style: AppTextStyles.label,
                              ),
                            ),
                            if (hasDraft && open)
                              AppPill(
                                label: 'Ada draf',
                                background: AppColors.partialBg,
                                foreground: AppColors.partialFg,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.xs + 2),
                        _ProgressBar(
                          value: d.itemCount == 0
                              ? 0
                              : d.fulfilledItemCount / d.itemCount,
                          color: accent,
                        ),
                      ] else if (hasDraft && open) ...[
                        const SizedBox(height: AppSpace.sm),
                        AppPill(
                          label: 'Ada draf',
                          background: AppColors.partialBg,
                          foreground: AppColors.partialFg,
                        ),
                      ],
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

/// Progress Partial yang tumbuh saat pertama tampil, bukan langsung penuh.
class _ProgressBar extends StatelessWidget {
  final double value;
  final Color color;

  const _ProgressBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: AppMotion.of(context, AppMotion.gentle),
        curve: AppMotion.curveOf(context, AppMotion.enter),
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: 6,
          backgroundColor: AppColors.pendingBg,
          color: color,
        ),
      ),
    );
  }
}
