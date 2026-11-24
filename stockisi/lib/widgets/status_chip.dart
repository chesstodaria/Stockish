import 'package:flutter/material.dart';

import '../data/transaction_rules.dart';
import '../theme/app_colors.dart';
import 'app_pill.dart';

/// Chip status item: latar pastel, teks gelap, ikon, dan label.
///
/// Status tidak pernah disampaikan hanya lewat warna, dan labelnya memakai
/// istilah Indonesia yang dipakai operator: Belum, Parsial, Selesai.
class StatusChip extends StatelessWidget {
  final ItemStatus status;
  final bool dense;

  const StatusChip(this.status, {super.key, this.dense = true});

  static (Color, Color, IconData) styleOf(ItemStatus status) => switch (status) {
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

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = styleOf(status);
    return AppPill(
      label: status.label,
      background: background,
      foreground: foreground,
      icon: icon,
      dense: dense,
    );
  }
}
