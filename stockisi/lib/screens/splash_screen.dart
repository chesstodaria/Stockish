import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/auth_repository.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import '../widgets/stockisi_wordmark.dart';
import 'app_routes.dart';

/// Memeriksa sesi tersimpan lalu mengarahkan ke halaman utama atau login.
/// Penyimpanan sesi di perangkat dikerjakan di Tahap 2.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

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
    final auth = context.read<AuthRepository>();
    var signedIn = false;
    try {
      signedIn = await auth.restoreSession() != null;
    } catch (_) {
      // Sesi tidak bisa dibaca: anggap belum login.
    }
    if (!mounted) return;
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
          ],
        ),
      ),
    );
  }
}
