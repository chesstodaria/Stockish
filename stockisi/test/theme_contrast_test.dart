import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockisi/theme/app_colors.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  // Pasangan teks/latar yang dipakai di app. Minimal WCAG AA 4,5:1.
  final pairs = <String, (Color, Color)>{
    'teks utama di latar': (AppColors.textPrimary, AppColors.background),
    'teks sekunder di latar': (AppColors.textSecondary, AppColors.background),
    'teks sekunder di permukaan redup':
        (AppColors.textSecondary, AppColors.surfaceMuted),
    'putih di navy': (AppColors.onNavy, AppColors.navy),
    'RCV': (AppColors.receivingFg, AppColors.receivingBg),
    'INT': (AppColors.intransitFg, AppColors.intransitBg),
    'Pending': (AppColors.pendingFg, AppColors.pendingBg),
    'Partial': (AppColors.partialFg, AppColors.partialBg),
    'Complete': (AppColors.completeFg, AppColors.completeBg),
    'Sudah terpenuhi': (AppColors.fulfilledFg, AppColors.fulfilledBg),
    'error': (AppColors.errorFg, AppColors.errorBg),
    'error di permukaan': (AppColors.error, AppColors.surface),
  };

  for (final entry in pairs.entries) {
    test('kontras ${entry.key} minimal 4,5:1', () {
      final (fg, bg) = entry.value;
      expect(contrast(fg, bg), greaterThanOrEqualTo(4.5));
    });
  }
}
