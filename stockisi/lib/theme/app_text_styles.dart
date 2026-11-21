import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Gaya teks Stockisi. Satu keluarga font (Plus Jakarta Sans, dibundel di
/// `assets/fonts/`), hierarki lewat ukuran, ketebalan, dan jarak.
abstract final class AppTextStyles {
  static const fontFamily = 'PlusJakartaSans';

  static const _tabular = [FontFeature.tabularFigures()];

  /// Nama aplikasi di Splash dan Login.
  static const wordmark = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.navy,
  );

  static const headline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const bodyStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 1.45,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const bodySecondary = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Kode barang, nomor dokumen, nomor rak.
  static const code = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: AppColors.textSecondary,
    fontFeatures: _tabular,
  );

  /// Badge dan chip.
  static const chip = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );

  static const button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
  );

  /// Angka kuantitas, besar supaya terbaca dari jarak lengan.
  static const quantityLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    height: 1.1,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );

  static const quantity = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    height: 1.15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );
}
