import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

/// Pesan kesalahan di dalam form atau layar, bukan SnackBar, supaya tetap
/// terlihat sampai operator memperbaiki input. Dibacakan pembaca layar
/// begitu muncul.
class InlineErrorBanner extends StatelessWidget {
  final String message;

  const InlineErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: AppColors.errorBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.errorFg, size: AppSize.iconMd),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyStrong
                    .copyWith(color: AppColors.errorFg, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
