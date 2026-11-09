import 'package:flutter/material.dart';

/// Baris "Terakhir sync: ..." — dipakai bareng di Reference Document List,
/// Transaction History, Profile, dan Digital Stock Card supaya keempatnya
/// konsisten (22 Juli 2026, lihat 05_Decision_Log.md). Murni tampilan teks,
/// TIDAK ada tombol nempel di sini — tombol refresh ada di AppBar tiap
/// Screen (konsisten pola Reference Document List yang sudah ada duluan),
/// supaya tidak dobel tombol dengan pull-to-refresh yang juga selalu aktif.
class SyncStatusIndicator extends StatelessWidget {
  final DateTime? lastSyncTime;

  const SyncStatusIndicator({super.key, required this.lastSyncTime});

  static String _format(DateTime? time) {
    if (time == null) return 'Belum pernah sync';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';

    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return 'Hari ini, $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync, size: 13, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            'Terakhir sync: ${_format(lastSyncTime)}',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}