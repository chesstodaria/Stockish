import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/session_controller.dart';

/// Membungkus layar yang butuh sesi. Kalau tidak ada operator yang login
/// (link web dibuka langsung, atau baru saja logout), tumpukan layar
/// dikosongkan dan operator diarahkan ke [redirectTo].
class SessionGuard extends StatefulWidget {
  final Widget child;
  final String redirectTo;

  const SessionGuard({
    super.key,
    required this.child,
    required this.redirectTo,
  });

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard> {
  bool _redirecting = false;

  void _redirect() {
    if (_redirecting) return;
    _redirecting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(widget.redirectTo, (_) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<SessionController>().isSignedIn;
    if (!signedIn) {
      _redirect();
      return const Scaffold(body: SizedBox.shrink());
    }
    return widget.child;
  }
}

/// Tujuan link yang tidak dikenal atau tidak lengkap (misalnya URL web
/// tanpa nomor dokumen). Mengulang dari Splash, yang memilih tujuan sesuai
/// sesi.
class RestartFromSplash extends StatefulWidget {
  final String splashRoute;
  const RestartFromSplash({super.key, required this.splashRoute});

  @override
  State<RestartFromSplash> createState() => _RestartFromSplashState();
}

class _RestartFromSplashState extends State<RestartFromSplash> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(widget.splashRoute, (_) => false);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}
