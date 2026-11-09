import 'package:flutter/material.dart';
import 'sync_status_indicator.dart';

/// Gabungan SyncStatusIndicator + RefreshIndicator (pull-to-refresh) jadi
/// satu widget — dipakai di semua layar berisi list yang butuh sinkronisasi
/// data (Reference Document List, Transaction History, Profile, Stock
/// Card, Print QR). Mengurangi duplikasi ~15 baris jadi 1 widget per layar
/// (22 Juli 2026, lihat 05_Decision_Log.md — keputusan "tombol AppBar DAN
/// pull-to-refresh dua-duanya, di semua layar berisi list", diperluas ke
/// Print QR yang sebelumnya sengaja dikecualikan).
///
/// Cara pakai — ganti `Expanded(child: <body list Kamu>)` jadi:
/// ```
/// Expanded(
///   child: RefreshableListSection(
///     lastSyncTime: vm.lastSyncTime,
///     onRefresh: vm.loadDocuments, // atau vm.refresh
///     child: <body list Kamu>,
///   ),
/// )
/// ```
///
/// Set `showIndicator: false` kalau Screen sudah menampilkan indikator
/// sync-nya sendiri di tempat lain (mis. Profile — sejajar judul
/// "Riwayat Aktivitas", bukan di atas list) — supaya tidak dobel.
///
/// Tombol refresh AppBar TIDAK ikut di widget ini (posisinya beda-beda
/// tiap AppBar, harus tetap ditulis di `actions:` masing-masing Screen) —
/// pakai helper `refreshAppBarAction()` di bawah untuk itu, styling-nya
/// tetap konsisten.
class RefreshableListSection extends StatelessWidget {
  final DateTime? lastSyncTime;
  final Future<void> Function() onRefresh;
  final Widget child;
  final bool showIndicator;

  const RefreshableListSection({
    super.key,
    required this.lastSyncTime,
    required this.onRefresh,
    required this.child,
    this.showIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    final refreshable = RefreshIndicator(onRefresh: onRefresh, child: child);

    if (!showIndicator) return refreshable;

    return Column(
      children: [
        SyncStatusIndicator(lastSyncTime: lastSyncTime),
        const SizedBox(height: 8),
        Expanded(child: refreshable),
      ],
    );
  }
}

/// Tombol refresh AppBar — styling konsisten (ikon putih), dipakai di
/// `actions:` tiap Screen. Bukan Widget class karena cuma dipanggil sekali
/// per Screen dan tidak butuh state sendiri — fungsi sudah cukup.
Widget refreshAppBarAction(VoidCallback onPressed) {
  return IconButton(
    icon: const Icon(Icons.refresh, color: Colors.white),
    onPressed: onPressed,
  );
}