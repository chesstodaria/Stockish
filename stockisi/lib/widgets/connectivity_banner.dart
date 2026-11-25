import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/connectivity_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import '../theme/motion.dart';

/// Menampilkan banner tipis di atas isi layar ketika koneksi bermasalah.
///
/// Banner tidak menghalangi apa pun: operator tetap bisa membaca data yang
/// sudah ada dan mencoba lagi. Muncul dan hilang dengan animasi ukuran,
/// mengikuti `AppMotion`, dan langsung tanpa animasi bila pengguna meminta
/// gerak dikurangi.
class ConnectivityBannerHost extends StatelessWidget {
  final Widget child;

  const ConnectivityBannerHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final offline = context.watch<ConnectivityStatus>().isOffline;
    return Column(
      children: [
        AnimatedSize(
          duration: AppMotion.of(context, AppMotion.standard),
          curve: AppMotion.curveOf(context, AppMotion.enter),
          alignment: Alignment.topCenter,
          child: offline ? const _Banner() : const SizedBox(width: double.infinity),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.partialBg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 16,
              color: AppColors.partialFg,
            ),
            const SizedBox(width: AppSpace.sm),
            Flexible(
              child: Text(
                'Tidak ada koneksi. Data mungkin tidak terbaru.',
                style: AppTextStyles.code.copyWith(
                  color: AppColors.partialFg,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
