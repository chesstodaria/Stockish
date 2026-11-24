import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

/// Judul kecil di atas sebuah kelompok, misalnya
/// `PERLU DIPROSES · 3` atau `RIWAYAT MUTASI · 3`.
///
/// Huruf besar dan jarak antarhurufnya sedikit dilebarkan mengikuti gaya
/// *section header* pada daftar iOS.
class SectionHeader extends StatelessWidget {
  final String label;
  final String? trailing;

  const SectionHeader(this.label, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final text = trailing == null ? label : '$label  ·  $trailing';
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.code.copyWith(
        letterSpacing: 0.6,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// Jarak vertikal pendek yang dipakai berulang di layar.
class VGap extends StatelessWidget {
  final double height;

  const VGap(this.height, {super.key});

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

/// Garis pemisah antar baris di dalam [GroupedList], menjorok 16 dp dari
/// kiri supaya sejajar dengan teks, bukan dengan tepi kartu.
class InsetDivider extends StatelessWidget {
  const InsetDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: AppSpace.lg),
      child: Divider(height: 1),
    );
  }
}
