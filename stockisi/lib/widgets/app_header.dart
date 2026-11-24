import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/session_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import 'app_pill.dart';

/// Header bersama untuk keempat tab: judul layar di kiri, konteks operator
/// di kanan (`WH01 · Budi`).
///
/// Ini menjawab pertanyaan pertama panduan Apple: *di mana aku?* Sebelumnya
/// nama operator dan gudang hanya terlihat di tab Profil, yaitu tab
/// keempat, sehingga operator tidak punya cara cepat memastikan dia sedang
/// melihat gudang yang benar.
class AppHeader extends StatelessWidget {
  final String title;

  const AppHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final operator = context.watch<SessionController>().operator;
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTextStyles.headline)),
        if (operator != null)
          AppPill(
            label: '${operator.warehouseCode} · ${_firstName(operator.name)}',
            background: AppColors.surfaceMuted,
            foreground: AppColors.textPrimary,
            dense: true,
          ),
      ],
    );
  }

  static String _firstName(String full) {
    final parts = full.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? full : parts.first;
  }
}

/// Jarak aman di bawah header sebelum konten dimulai.
const kHeaderGap = SizedBox(height: AppSpace.lg);
