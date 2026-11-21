import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/repositories/repositories.dart';
import 'screens/app_routes.dart';
import 'services/session_controller.dart';
import 'theme/app_theme.dart';

/// Root app. Repository disediakan lewat `provider`, jadi layar memintanya
/// dengan `context.read<AuthRepository>()` dan tidak tahu implementasinya.
class StockisiApp extends StatelessWidget {
  final Repositories repositories;

  const StockisiApp({super.key, required this.repositories});

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
        ChangeNotifierProvider(
            create: (_) => SessionController(repositories.auth)),
      ],
      child: MaterialApp(
        title: 'Stockisi',
        debugShowCheckedModeBanner: false,
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
