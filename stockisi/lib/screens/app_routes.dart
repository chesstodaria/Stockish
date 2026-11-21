import 'package:flutter/material.dart';

import 'documents/scanner_screen.dart';
import 'documents/transaction_detail_screen.dart';
import 'documents/transaction_summary_screen.dart';
import 'history/history_detail_screen.dart';
import 'home_shell.dart';
import 'login_screen.dart';
import 'splash_screen.dart';
import 'stock/qr_label_screen.dart';
import 'stock/stock_card_detail_screen.dart';

/// Nama route semua layar yang dibuka lewat Navigator. Keempat tab
/// (Dokumen, Kartu Stok, Riwayat, Profil) tinggal di dalam [HomeShell].
/// Konfirmasi Submit (layar 7, Tabel 2.1) berupa dialog di Ringkasan.
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

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final arg = settings.arguments;
    final Widget? page = switch (settings.name) {
      splash => const SplashScreen(),
      login => const LoginScreen(),
      home => const HomeShell(),
      transactionDetail =>
        TransactionDetailScreen(documentNumber: arg as String),
      transactionSummary =>
        TransactionSummaryScreen(documentNumber: arg as String),
      scanner => const ScannerScreen(),
      stockCardDetail => StockCardDetailScreen(itemCode: arg as String),
      qrLabel => QrLabelScreen(itemCode: arg as String),
      historyDetail => HistoryDetailScreen(transactionNumber: arg as String),
      _ => null,
    };
    if (page == null) return null;
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
