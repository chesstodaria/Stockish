import 'package:flutter/material.dart';

/// Satu-satunya tempat kode warna ditulis. Layar dan widget memakai nama
/// di sini, tidak pernah `Color(0x...)` langsung.
///
/// Setiap pasangan teks dan latar di bawah dicek kontrasnya (minimal
/// WCAG AA 4,5:1) di `test/theme_contrast_test.dart`.
abstract final class AppColors {
  /// Navy dari kode lama (`stockish/lib/constants/app_colors.dart`).
  /// Warna teks utama dan aksen.
  static const navy = Color(0xFF1B2A5E);
  static const onNavy = Color(0xFFFFFFFF);

  /// Permukaan putih hangat.
  static const background = Color(0xFFFAF8F4);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF1EEE7);
  static const border = Color(0xFFE2DDD2);

  static const textPrimary = navy;
  static const textSecondary = Color(0xFF4A536B);

  /// Identitas Receiving: mint.
  static const receivingBg = Color(0xFFD7F0E4);
  static const receivingFg = Color(0xFF0B5A3E);

  /// Identitas Intransit: peach.
  static const intransitBg = Color(0xFFFCE2D1);
  static const intransitFg = Color(0xFF86370C);

  /// Status item: latar pastel, teks gelap.
  static const pendingBg = Color(0xFFE8EAEE);
  static const pendingFg = Color(0xFF363D4E);
  static const partialBg = Color(0xFFFFEFB8);
  static const partialFg = Color(0xFF5F4300);
  static const completeBg = Color(0xFFD4EFDA);
  static const completeFg = Color(0xFF17532A);
  static const fulfilledBg = surfaceMuted;
  static const fulfilledFg = textSecondary;

  static const error = Color(0xFFB3261E);
  static const errorBg = Color(0xFFFBE4E1);
  static const errorFg = Color(0xFF8C1D18);
}
