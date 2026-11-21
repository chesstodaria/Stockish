import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

class PlaceholderLink {
  final String label;
  final VoidCallback onTap;
  const PlaceholderLink(this.label, this.onTap);
}

/// Layar sementara untuk layar yang belum dikerjakan. Menyebut tahap yang
/// akan mengerjakannya dan menyediakan tautan ke layar lanjutannya supaya
/// routing bisa ditelusuri.
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final String stage;
  final String description;
  final List<PlaceholderLink> links;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.stage,
    required this.description,
    this.links = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.screen),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.construction_rounded,
                    color: AppColors.textSecondary),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dikerjakan di $stage',
                          style: AppTextStyles.bodyStrong),
                      const SizedBox(height: AppSpace.xs),
                      Text(description, style: AppTextStyles.bodySecondary),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final link in links) ...[
            const SizedBox(height: AppSpace.md),
            OutlinedButton(
              onPressed: link.onTap,
              child: Text(link.label),
            ),
          ],
        ],
      ),
    );
  }
}
