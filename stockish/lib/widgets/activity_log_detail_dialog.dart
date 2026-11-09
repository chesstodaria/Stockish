import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activity_log.dart';
import '../models/reference_document.dart';

/// Dialog detail transaksi (19 Juli 2026) — dipanggil dari Profile
/// (Riwayat Aktivitas) DAN Transaction History, dua-duanya nampilin data
/// dari ActivityLog yang sama. Dibuat sebagai function/widget bersama
/// (bukan diduplikasi ke 2 Screen), konsisten dengan prinsip 1 sumber data
/// yang sudah dipakai di 02_Feature_TransactionHistory.md.
///
/// Nampilin snapshot item dari ActivityLog.items (Opsi B) — kalau kosong
/// (entry lama sebelum fitur ini ada, atau data korup), tampil pesan
/// "tidak tersedia" alih-alih error/kosong tanpa penjelasan.
void showActivityLogDetail(BuildContext context, ActivityLog log) {
  final isReceiving = log.type == TransactionType.receiving;
  final isPartial = log.status == DocumentStatus.partial;
  final typeColor = isReceiving ? Colors.blue : Colors.deepOrange;
  final statusColor = isPartial ? Colors.orange : Colors.green;

  showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(isReceiving ? Icons.inbox : Icons.outbox, color: typeColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      log.referenceNumber,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  _statusChip(isReceiving ? 'Receiving' : 'Intransit', typeColor),
                  _statusChip(isPartial ? 'Partial' : 'Selesai', statusColor),
                ],
              ),
              const SizedBox(height: 16),
              _detailRow('Tanggal Submit', DateFormat('dd MMM yyyy, HH:mm').format(log.date)),
              _detailRow('Disubmit oleh', 'NIK ${log.submittedByNik}'),
              _detailRow('Warehouse', log.warehouseCode),
              const SizedBox(height: 16),
              const Text('Item', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Flexible(
                child: log.items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Detail item tidak tersedia untuk entry ini.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: log.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 16),
                        itemBuilder: (context, index) {
                          final item = log.items[index];
                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.itemName,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    Text(
                                      item.itemCode,
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${item.quantity} ${item.uom}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _statusChip(String label, Color color) {
  return Chip(
    label: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white)),
    backgroundColor: color,
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
  );
}

Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ],
    ),
  );
}