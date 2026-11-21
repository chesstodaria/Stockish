import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/session_controller.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import '../widgets/stockisi_wordmark.dart';
import 'app_routes.dart';

/// Memeriksa sesi tersimpan, lalu ke halaman utama (tab Dokumen) atau Login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Waktu tampil minimum supaya Splash tidak sekadar berkedip.
  static const minimumDisplay = Duration(milliseconds: 700);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final session = context.read<SessionController>();
    final results = await Future.wait([
      session.restore(),
      Future<void>.delayed(SplashScreen.minimumDisplay),
    ]);
    if (!mounted) return;
    final signedIn = results.first as bool;
    Navigator.of(context)
        .pushReplacementNamed(signedIn ? AppRoutes.home : AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StockisiWordmark(),
            SizedBox(height: AppSpace.sm),
            Text('Gudang rapi dari genggaman',
                style: AppTextStyles.bodySecondary),
            SizedBox(height: AppSpace.xxl),
            SizedBox.square(
              dimension: AppSize.iconMd,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
