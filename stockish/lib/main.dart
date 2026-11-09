// lib/main.dart (REPLACE FULL — tambah Listener global buat idle-timeout, 19 Agustus 2026)
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/lock_timer_service.dart';
import 'services/lock_validation_service.dart';
import 'services/session/session_service.dart';
import 'services/connectivity_service.dart';
import 'services/database/database_service.dart';
import 'constants/api_constants.dart';
import 'utils/route_observer.dart'; // 🆕 (26 Agustus 2026)

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService().database;
  await ApiConstants.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: LockTimerService()),
        ChangeNotifierProvider.value(value: SessionService()),
        ChangeNotifierProvider.value(value: LockValidationService()),
        ChangeNotifierProvider.value(value: ConnectivityService()), // 🆕 (7 Agustus 2026)
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    SessionService().addListener(_onForceLogout);
    // 🆕 (7 Agustus 2026) — Connectivity Banner, App-wide (nyala sejak app
    // dibuka, bahkan sebelum login — koneksi relevan di Login Screen juga).
    ConnectivityService().start();
  }

  @override
  void dispose() {
    SessionService().removeListener(_onForceLogout);
    ConnectivityService().stop();
    super.dispose();
  }

  void _onForceLogout() {
    final overlayContext = navigatorKey.currentState?.overlay?.context;
    if (overlayContext == null) return;

    final message = SessionService().lastInvalidMessage ??
        'Sesi Anda telah berakhir. Silakan login kembali.';

    navigatorKey.currentState!.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );

    showDialog(
      context: overlayContext,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Sesi Berakhir'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver], // 🆕 (26 Agustus 2026)
      title: 'StockFlow',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const SplashScreen(),
      // 🆕 (7 Agustus 2026) — banner koneksi global, ditumpuk di ATAS Screen
      // manapun yang lagi aktif. Nempel 1x di sini, tidak perlu edit tiap
      // Screen satu-satu.
      builder: (context, child) {
        return Listener(
          // 🆕 (19 Agustus 2026) — deteksi aktivitas GLOBAL (tap/scroll/drag
          // di mana pun di app), reset idle-timeout SessionService. No-op
          // aman kalau sesi belum aktif (recordActivity() guard internal).
          // Dipasang di level PALING LUAR (builder, bukan per-Screen)
          // supaya tidak perlu sentuh Screen manapun satu-satu — konsisten
          // pola Connectivity Banner di atas.
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => SessionService().recordActivity(),
          child: Stack(
            children: [
              if (child != null) child,
              Consumer<ConnectivityService>(
                builder: (context, connectivity, _) {
                  if (connectivity.isConnected) return const SizedBox.shrink();
                  return Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Container(
                        width: double.infinity,
                        color: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off, color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'Koneksi terputus',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}