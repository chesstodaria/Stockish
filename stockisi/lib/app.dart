import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/repositories/repositories.dart';
import 'screens/app_routes.dart';
import 'screens/documents/scanner_screen.dart';
import 'services/connectivity_status.dart';
import 'services/device_id_store.dart';
import 'services/scan_launcher.dart';
import 'services/session_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/connectivity_banner.dart';

/// Root app. Repository disediakan lewat `provider`, jadi layar memintanya
/// dengan `context.read<AuthRepository>()` dan tidak tahu implementasinya.
class StockisiApp extends StatelessWidget {
  final Repositories repositories;

  /// Cara membuka scanner. Bawaan: kamera ([launchCameraScanner]).
  final ScanLauncher scanLauncher;

  /// Identitas perangkat untuk pengecekan sesi tunggal.
  final DeviceIdStore _deviceIds;

  StockisiApp({
    super.key,
    required this.repositories,
    this.scanLauncher = launchCameraScanner,
    DeviceIdStore? deviceIds,
  }) : _deviceIds = deviceIds ?? DeviceIdStore();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: repositories.auth),
        Provider<ReferenceDocumentRepository>.value(
            value: repositories.documents),
        Provider<DraftRepository>.value(value: repositories.drafts),
        Provider<TransactionRepository>.value(
            value: repositories.transactions),
        Provider<StockCardRepository>.value(value: repositories.stockCard),
        Provider<AuditRepository>.value(value: repositories.audit),
        Provider<DocumentClaimRepository>.value(value: repositories.claims),
        Provider<SessionDeviceRepository>.value(
            value: repositories.sessionDevices),
        Provider<DeviceIdStore>.value(value: _deviceIds),
        ChangeNotifierProvider(create: (_) => ConnectivityStatus()),
        ChangeNotifierProvider(
            create: (_) => SessionController(repositories.auth)),
        Provider<ScanLauncher>.value(value: scanLauncher),
      ],
      child: MaterialApp(
        title: 'Stockisi',
        debugShowCheckedModeBanner: false,
        builder: (context, child) =>
            ConnectivityBannerHost(child: child ?? const SizedBox.shrink()),
        theme: AppTheme.light(),
        locale: const Locale('id'),
        supportedLocales: const [Locale('id')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        initialRoute: AppRoutes.splash,
        // Selalu mulai dari Splash, termasuk saat halaman web dimuat ulang
        // di URL lain (misalnya /beranda). Splash yang memutuskan tujuan
        // berdasarkan sesi, jadi tidak ada layar yang terbuka tanpa sesi.
        onGenerateInitialRoutes: (_) => [
          AppRoutes.onGenerateRoute(
              const RouteSettings(name: AppRoutes.splash)),
        ],
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}
