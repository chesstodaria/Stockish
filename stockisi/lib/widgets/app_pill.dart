import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

/// Satu-satunya implementasi "pill" di aplikasi: label pendek berlatar
/// pastel dengan sudut penuh.
///
/// Dibuat sebagai satu widget supaya badge jenis dokumen, chip status item,
/// tag draf, dan chip konteks tidak lagi punya padding dan radius berbeda
/// sendiri-sendiri.
class AppPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  /// Versi rapat: dipakai badge kecil di dalam baris.
  final bool dense;

  const AppPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpace.sm : AppSpace.sm + 2,
        vertical: dense ? 3 : AppSpace.xs + 1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 13 : 14, color: foreground),
            const SizedBox(width: AppSpace.xs),
          ],
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.chip.copyWith(color: foreground),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
