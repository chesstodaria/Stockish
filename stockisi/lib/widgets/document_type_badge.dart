import 'package:flutter/material.dart';

import '../models/document_type.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

/// Badge RCV (mint) atau INT (peach). Teks kode selalu tampil, jadi jenis
/// dokumen tidak hanya disampaikan lewat warna.
class DocumentTypeBadge extends StatelessWidget {
  final DocumentType type;

  /// Tampilkan nama lengkap ("Receiving") alih-alih kode ("RCV").
  final bool showLabel;

  const DocumentTypeBadge(this.type, {super.key, this.showLabel = false});

  static Color background(DocumentType type) => type == DocumentType.receiving
      ? AppColors.receivingBg
      : AppColors.intransitBg;

  static Color foreground(DocumentType type) => type == DocumentType.receiving
      ? AppColors.receivingFg
      : AppColors.intransitFg;

  @override
  Widget build(BuildContext context) {
    final icon = type == DocumentType.receiving
        ? Icons.south_west_rounded
        : Icons.north_east_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: background(type),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground(type)),
          const SizedBox(width: AppSpace.xs),
          Text(
            showLabel ? type.label : type.code,
            style: AppTextStyles.chip.copyWith(color: foreground(type)),
          ),
        ],
      ),
    );
  }
}
