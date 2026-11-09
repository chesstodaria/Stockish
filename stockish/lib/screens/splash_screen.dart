// lib/screens/splash_screen.dart (REPLACE FULL — Remember Login DIMATIKAN, restore dihapus total, 18 Agustus 2026)
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../services/session/session_storage_service.dart';

// Warna khusus background Splash Screen, diambil langsung dari
// background logo (Logo_Splash.png) — sengaja terpisah dari
// kPrimaryColor di app_colors.dart supaya tidak mengubah warna
// utama yang dipakai komponen UI lain.
const Color kSplashBackgroundColor = Color(0xFF00102A);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  /// 🔧 (18 Agustus 2026) — REDESAIN TOTAL. Remember Login DIMATIKAN
  /// (Restrukturisasi Auth Tim IT, 05_Decision_Log.md 18 Agustus 2026) —
  /// Splash TIDAK LAGI coba restore sesi apa pun. Sekarang cuma 2 tugas:
  /// 1. Tampil minimal sebentar (UX murni, sama seperti sebelumnya).
  /// 2. PURGE data lama (best-effort, fire-and-forget) — device yang
  ///    pernah pakai Remember Login SEBELUM update ini terpasang punya
  ///    data tersimpan yang sekarang orphaned (tidak akan pernah dibaca
  ///    lagi) — dibersihkan sekali tiap app dibuka, aman dipanggil
  ///    berulang/pada storage kosong (no-op). Lihat SessionStorageService
  ///    untuk detail alasan `clearUser()` dipertahankan.
  ///
  /// Selalu berakhir di LoginScreen — tidak ada lagi jalur auto-login.
  Future<void> _initialize() async {
    // Fire-and-forget — purge tidak boleh menunda splash, dan kegagalannya
    // (mis. storage device bermasalah) tidak boleh menghalangi ke Login.
    unawaited(SessionStorageService().clearUser());

    await Future.delayed(
      kDebugMode ? const Duration(milliseconds: 300) : const Duration(seconds: 2),
    );
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSplashBackgroundColor,
      body: Center(
        child: Image.asset(
          'assets/images/Logo_Splash.png',
          width: 180,
        ),
      ),
    );
  }
}