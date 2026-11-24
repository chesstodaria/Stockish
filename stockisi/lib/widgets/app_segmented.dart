import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import '../theme/motion.dart';
import 'pressable.dart';

/// Satu pilihan di dalam [AppSegmented].
class AppSegment<T> {
  final T value;
  final String label;

  const AppSegment(this.value, this.label);
}

/// Kontrol segmen bergaya `UISegmentedControl`: track muted, penanda putih
/// yang **meluncur** ke pilihan aktif.
///
/// Penandanya dibuat sebagai satu elemen yang bergerak, bukan dua latar
/// yang berganti warna, karena perpindahan posisi itulah yang membuat
/// kontrol ini terasa seperti kontrol asli iOS.
class AppSegmented<T> extends StatelessWidget {
  final List<AppSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  const AppSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final index = segments.indexWhere((s) => s.value == value);
    final count = segments.length;

    return SizedBox(
      height: 40,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - AppSpace.xs - 2) / count;
          return Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.sm + 1),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: AppMotion.of(context, AppMotion.quick),
                  curve: AppMotion.curveOf(context, AppMotion.enter),
                  left: AppSpace.xs / 2 + index * itemWidth,
                  top: AppSpace.xs / 2,
                  bottom: AppSpace.xs / 2,
                  width: itemWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.sm - 1),
                      border: Border.all(color: AppColors.border),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final segment in segments)
                      Expanded(
                        child: Pressable(
                          onTap: () => onChanged(segment.value),
                          child: Center(
                            child: Text(
                              segment.label,
                              style: AppTextStyles.label.copyWith(
                                color: segment.value == value
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
