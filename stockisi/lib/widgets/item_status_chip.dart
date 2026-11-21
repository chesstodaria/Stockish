import 'package:flutter/material.dart';

import '../data/transaction_rules.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

/// Chip status item: latar pastel, teks gelap, ikon, dan label. Status
/// tidak pernah disampaikan hanya lewat warna.
class ItemStatusChip extends StatelessWidget {
  final ItemStatus status;

  const ItemStatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (status) {
      ItemStatus.pending => (
          AppColors.pendingBg,
          AppColors.pendingFg,
          Icons.radio_button_unchecked_rounded,
        ),
      ItemStatus.partial => (
          AppColors.partialBg,
          AppColors.partialFg,
          Icons.incomplete_circle_rounded,
        ),
      ItemStatus.complete => (
          AppColors.completeBg,
          AppColors.completeFg,
          Icons.check_circle_rounded,
        ),
      ItemStatus.fulfilled => (
          AppColors.fulfilledBg,
          AppColors.fulfilledFg,
          Icons.done_all_rounded,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: AppSpace.xs),
          Text(status.label, style: AppTextStyles.chip.copyWith(color: fg)),
        ],
      ),
    );
  }
}
