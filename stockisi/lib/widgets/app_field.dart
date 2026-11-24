import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

/// Isian formulir: label kecil di atas, kotak putih bergaris, tinggi 56.
///
/// Berbeda dari `InputDecorationTheme` bawaan yang dipakai kolom pencarian
/// (muted tanpa garis), isian ini butuh batas yang jelas karena berada di
/// dalam formulir dan sering menjadi fokus utama layar.
class AppField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? hint;
  final bool obscure;
  final bool autofocus;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final String? errorText;

  const AppField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.obscure = false,
    this.autofocus = false,
    this.trailing,
    this.onChanged,
    this.keyboardType,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.code),
        const SizedBox(height: AppSpace.xs + 2),
        Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: errorText == null ? AppColors.border : AppColors.error,
              width: errorText == null ? 1 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  autofocus: autofocus,
                  onChanged: onChanged,
                  keyboardType: keyboardType,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    hintText: hint,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpace.lg - 2,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: AppSpace.xs + 2),
          Text(
            errorText!,
            style: AppTextStyles.code.copyWith(color: AppColors.errorFg),
          ),
        ],
      ],
    );
  }
}
