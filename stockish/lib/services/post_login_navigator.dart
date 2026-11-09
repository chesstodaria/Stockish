// lib/services/post_login_navigator.dart (BARU — 5 Agustus 2026)
//
// Kenapa file terpisah, bukan taruh di main.dart: main.dart cuma nyala
// SEKALI di awal app lifecycle (nyiapin MaterialApp + listener global
// force-logout), BUKAN dilewatin tiap kali ada user baru selesai
// login/restore sesi. SplashScreen (_tryRestoreSession) dan LoginScreen
// (_handleLogin) itu 2 EVENT terpisah yang masing-masing baru punya objek
// `user` di tangan SETELAH proses mereka sendiri selesai — main.dart tidak
// pernah punya akses ke momen itu tanpa restrukturisasi navigasi besar.
//
// Solusinya: 1 helper shared yang dipanggil dari KEDUA titik (Splash
// setelah restore sukses, Login setelah login sukses) — logic reclaim
// cuma ada 1 kali, tapi tetap jalan dari titik yang tepat.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/reference_document.dart';
import '../screens/dashboard_screen.dart';
import '../screens/reference_document_list_screen.dart';
import '../screens/transaction_detail_screen.dart';
import '../services/lock_timer_service.dart';
import '../repositories/reference_document_repository.dart';

class PostLoginNavigator {
  /// Dipanggil setelah SessionService().start(user) sukses (baik dari
  /// restore otomatis di Splash, maupun login manual di LoginScreen).
  /// Cek dulu apakah NIK ini masih pegang lock aktif di dokumen manapun
  /// (skenario app di-kill via recent-apps, bukan back manual —
  /// unlockDocument() tidak sempat kepanggil, lihat 05_Decision_Log.md
  /// 23 Juli 2026 "Reclaim Lock"). Kalau ADA, langsung reclaim & arahkan
  /// ke Transaction Detail (skip Dashboard). Kalau TIDAK ADA / gagal
  /// (best-effort, network error dsb), arahkan ke Dashboard seperti biasa.
  ///
  /// `context` harus masih `mounted` saat dipanggil — pemanggil wajib cek
  /// `mounted` sebelum memanggil ini (sama seperti pola existing di kedua
  /// Screen).
  static Future<void> resolve(BuildContext context, User user) async {
    final reclaimTarget = await _tryReclaimActiveLock(user);
    if (!context.mounted) return;

    if (reclaimTarget != null) {
      debugPrint('🔍[LOCK] PostLoginNavigator: reclaim otomatis ke ${reclaimTarget.doc.referenceNumber}');
      LockTimerService().start(
        reclaimTarget.doc.referenceNumber,
        expiresAt: reclaimTarget.expiresAt,
        token: user.token,
      );

      // ⚠️ FIX (5 Agustus 2026, revisi lanjutan) — versi sebelumnya push
      // stack jadi [Dashboard, Detail] (Dashboard pushReplacement, lalu
      // Detail push langsung di atasnya) — ini SUDAH menutup bug freeze
      // "Batalkan Proses" (Navigator.pop() sekarang punya tujuan), TAPI
      // bikin tombol back dari Detail mendarat di Dashboard, bukan di
      // Reference Document List seperti alur normal buka dokumen
      // (Dashboard → List → Detail). Fix: sisipkan List di antara
      // Dashboard dan Detail, supaya stack jadi [Dashboard, List,
      // Detail] — persis sama seperti kalau operator buka dokumen
      // manual dari List (lihat `_openDocument()` di
      // reference_document_list_screen.dart). Back dari Detail sekarang
      // ke List, back dari List ke Dashboard, tidak ada pengecualian
      // khusus untuk jalur reclaim.
      final navigator = Navigator.of(context);
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => DashboardScreen(user: user)),
      );
      navigator.push(
        MaterialPageRoute(builder: (_) => ReferenceDocumentListScreen(user: user)),
      );
      navigator.push(
        MaterialPageRoute(
          builder: (_) => TransactionDetailScreen(document: reclaimTarget.doc, user: user),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => DashboardScreen(user: user)),
    );
  }

  /// Best-effort: kalau gagal (network/parsing error apapun), JANGAN
  /// blokir alur normal — anggap tidak ada reclaim, lanjut ke Dashboard
  /// seperti biasa. Ini prasyarat kenyamanan tambahan, bukan bagian
  /// kritis dari alur login yang boleh gagal total.
  static Future<_ReclaimTarget?> _tryReclaimActiveLock(User user) async {
    try {
      final docs = await ReferenceDocumentRepository().getList(user.token, warehouseName: user.warehouseName);
      final lockedByMe = docs.where(
        (d) => d.status == DocumentStatus.locked && d.lockedByNik == user.nik,
      );
      if (lockedByMe.isEmpty) return null;

      final target = lockedByMe.first;
      final result = await ReferenceDocumentRepository().lockDocument(target.referenceNumber, user.token);
      if (!result.locked) {
        // Race kecil kemungkinan: dokumen sempat di-force-unlock Admin
        // TEPAT di antara GET List & lockDocument() di atas — anggap
        // tidak ada reclaim, biar Dashboard yang jadi tujuan normal.
        return null;
      }
      return _ReclaimTarget(doc: target, expiresAt: result.expiresAt);
    } catch (e) {
      debugPrint('🔍[LOCK] PostLoginNavigator: cek reclaim gagal (diabaikan, lanjut normal): $e');
      return null;
    }
  }
}

/// Kecil, cuma dipakai internal — bungkus hasil dokumen + expiresAt dari
/// reclaim supaya tidak perlu 2 variabel terpisah.
class _ReclaimTarget {
  final ReferenceDocument doc;
  final DateTime? expiresAt;
  const _ReclaimTarget({required this.doc, required this.expiresAt});
}