import 'package:flutter/material.dart';

import '../data/transaction_rules.dart';
import 'status_chip.dart';

/// Nama lama untuk [StatusChip]. Dipertahankan sementara supaya pemanggil
/// yang belum dimigrasi tetap berjalan.
class ItemStatusChip extends StatelessWidget {
  final ItemStatus status;

  const ItemStatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) => StatusChip(status, dense: false);
}
