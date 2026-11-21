import 'package:flutter/material.dart';

import 'documents/scanner_screen.dart';
import 'documents/transaction_detail_screen.dart';
import 'documents/transaction_summary_screen.dart';
import 'history/history_detail_screen.dart';
import 'home_shell.dart';
import 'login_screen.dart';
import 'session_guard.dart';
import 'splash_screen.dart';
import 'stock/qr_label_screen.dart';
import 'stock/stock_card_detail_screen.dart';

/// Nama route semua layar yang dibuka lewat Navigator. Keempat tab
/// (Dokumen, Kartu Stok, Riwayat, Profil) tinggal di dalam [HomeShell].
/// Konfirmasi Submit (layar 7, Tabel 2.1) berupa dialog di Ringkasan.
///
/// Semua route selain Splash dan Login dijaga [SessionGuard]. Route yang
/// tidak dikenal atau argumennya tidak lengkap (bisa terjadi lewat URL di
/// web) diulang dari Splash.
abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const home = '/beranda';
  static const transactionDetail = '/dokumen/detail';
  static const transactionSummary = '/dokumen/ringkasan';
  static const scanner = '/dokumen/scan';
  static const stockCardDetail = '/kartu-stok/detail';
  static const qrLabel = '/kartu-stok/label-qr';
  static const historyDetail = '/riwayat/detail';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final arg = settings.arguments;
    final text = arg is String && arg.isNotEmpty ? arg : null;

    Widget? public;
    Widget? protected;
    switch (settings.name) {
      case splash:
        public = const SplashScreen();
      case login:
        public = const LoginScreen();
      case home:
        protected = const HomeShell();
      case scanner:
        protected = const ScannerScreen();
      case transactionDetail when text != null:
        protected = TransactionDetailScreen(documentNumber: text);
      case transactionSummary when text != null:
        protected = TransactionSummaryScreen(documentNumber: text);
      case stockCardDetail when text != null:
        protected = StockCardDetailScreen(itemCode: text);
      case qrLabel when text != null:
        protected = QrLabelScreen(itemCode: text);
      case historyDetail when text != null:
        protected = HistoryDetailScreen(transactionNumber: text);
    }

    final Widget page = public ??
        (protected != null
            ? SessionGuard(redirectTo: login, child: protected)
            : const RestartFromSplash(splashRoute: splash));
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
