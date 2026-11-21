import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// Tombol aksi utama setinggi 56 dp (Scan, Submit, Simpan). Saat [loading],
/// tombol menampilkan indikator dan tidak bisa ditekan lagi, untuk mencegah
/// aksi ganda.
class PrimaryActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  const PrimaryActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox.square(
            dimension: AppSize.iconMd,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.onNavy,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppSize.iconMd),
                const SizedBox(width: AppSpace.sm),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );
    return SizedBox(
      width: double.infinity,
      height: AppSize.primaryButton,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: loading
            ? FilledButton.styleFrom(
                disabledBackgroundColor: AppColors.navy,
                disabledForegroundColor: AppColors.onNavy,
              )
            : null,
        child: Semantics(
          label: loading ? '$label, sedang diproses' : null,
          child: child,
        ),
      ),
    );
  }
}
