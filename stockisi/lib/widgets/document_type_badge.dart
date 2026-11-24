import 'package:flutter/material.dart';

import '../models/document_type.dart';
import 'type_pill.dart';

/// Nama lama untuk [TypePill]. Dipertahankan sementara supaya pemanggil
/// yang belum dimigrasi tetap berjalan; implementasinya sudah memakai
/// `AppPill` bersama, jadi tidak ada lagi kode pill yang terduplikasi.
class DocumentTypeBadge extends StatelessWidget {
  final DocumentType type;
  final bool showLabel;

  const DocumentTypeBadge(this.type, {super.key, this.showLabel = false});

  static Color background(DocumentType type) => TypePill.background(type);

  static Color foreground(DocumentType type) => TypePill.foreground(type);

  @override
  Widget build(BuildContext context) =>
      TypePill(type, showLabel: showLabel, dense: false);
}
