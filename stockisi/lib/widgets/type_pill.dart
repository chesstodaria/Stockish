import 'package:flutter/material.dart';

import '../models/document_type.dart';
import '../theme/app_colors.dart';
import 'app_pill.dart';

/// Badge jenis dokumen: `RCV` bermint, `INT` berpeach.
///
/// Warna mengikuti `CONTEXT` bagian 9: mint adalah identitas Receiving dan
/// peach identitas Intransit. Kode jenisnya selalu ditulis, jadi jenis
/// dokumen tidak pernah disampaikan lewat warna saja.
class TypePill extends StatelessWidget {
  final DocumentType type;
  final bool showLabel;
  final bool dense;

  const TypePill(this.type, {super.key, this.showLabel = false, this.dense = true});

  static Color background(DocumentType type) => type == DocumentType.receiving
      ? AppColors.receivingBg
      : AppColors.intransitBg;

  static Color foreground(DocumentType type) => type == DocumentType.receiving
      ? AppColors.receivingFg
      : AppColors.intransitFg;

  @override
  Widget build(BuildContext context) {
    return AppPill(
      label: showLabel ? type.label : type.code,
      background: background(type),
      foreground: foreground(type),
      icon: type == DocumentType.receiving
          ? Icons.south_west_rounded
          : Icons.north_east_rounded,
      dense: dense,
    );
  }
}
