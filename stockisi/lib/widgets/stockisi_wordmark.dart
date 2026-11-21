import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

/// Logo sementara: nama "Stockisi" dalam bentuk teks dengan ikon gudang.
/// Diganti gambar kalau logo resmi sudah ada.
class StockisiWordmark extends StatelessWidget {
  const StockisiWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Stockisi',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.sm),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: AppColors.onNavy,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          const Text('Stockisi', style: AppTextStyles.wordmark),
        ],
      ),
    );
  }
}
