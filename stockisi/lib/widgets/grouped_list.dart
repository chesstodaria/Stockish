import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'section_header.dart';

/// Daftar bergaya *inset grouped* iOS: satu permukaan bersudut 16 dengan
/// garis pemisah tipis yang menjorok ke dalam.
///
/// Dipakai untuk data yang seragam dan tidak punya state per baris
/// (kartu stok, item transaksi, info akun). Data yang tiap barisnya punya
/// status sendiri (dokumen, transaksi) tetap memakai kartu terpisah.
class GroupedList extends StatelessWidget {
  final List<Widget> children;

  const GroupedList({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const InsetDivider());
      rows.add(children[i]);
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: rows),
    );
  }
}

/// Satu baris di dalam [GroupedList].
class GroupedRow extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const GroupedRow({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpace.lg,
      vertical: AppSpace.md,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(padding: padding, child: child);
  }
}
