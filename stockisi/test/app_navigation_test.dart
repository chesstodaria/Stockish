import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockisi/app.dart';
import 'package:stockisi/data/mock/mock_repositories.dart';
import 'package:stockisi/data/mock/mock_seed.dart';

Future<void> enterHome(WidgetTester tester) async {
  final backend = createSeededBackend(latency: Duration.zero);
  await tester.pumpWidget(
      StockisiApp(repositories: createMockRepositories(backend)));
  await tester.pumpAndSettle();
  await tester.enterText(
      find.widgetWithText(TextFormField, 'NIK'), MockNik.budi);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Kata sandi'), kMockPassword);
  await tester.tap(find.text('Masuk').last);
  await tester.pumpAndSettle();
}

Finder tab(String label) => find.descendant(
    of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets('Splash tanpa sesi mengarah ke Login, lalu halaman utama',
      (tester) async {
    await enterHome(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Dikerjakan di Tahap 3'), findsOneWidget);
  });

  testWidgets('keempat tab bisa dibuka tanpa error', (tester) async {
    await enterHome(tester);
    final expected = {
      'Dokumen': 'Tahap 3',
      'Kartu Stok': 'Tahap 4',
      'Riwayat': 'Tahap 5',
    };
    for (final e in expected.entries) {
      await tester.tap(tab(e.key));
      await tester.pumpAndSettle();
      expect(find.text('Dikerjakan di ${e.value}').hitTestable(),
          findsOneWidget,
          reason: e.key);
    }
    await tester.tap(tab('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Budi Santoso').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('routing ke layar turunan setiap tab', (tester) async {
    await enterHome(tester);

    Future<void> openAndBack(String link, String title) async {
      await tester.tap(find.text(link).hitTestable());
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget, reason: link);
    }

    // Tooltip tombol kembali sudah berbahasa Indonesia ("Kembali"), jadi
    // tester.pageBack() (mencari tooltip "Back") tidak dipakai.
    Future<void> back() async {
      await tester.tap(find.byTooltip('Kembali').hitTestable());
      await tester.pumpAndSettle();
    }

    await openAndBack('Buka Detail Transaksi (contoh)', 'PO-2611-0041');
    await openAndBack('Buka Scan QR', 'Scan QR');
    await back();
    await openAndBack('Buka Ringkasan Transaksi', 'Ringkasan Transaksi');
    await back();
    await back();

    await tester.tap(tab('Kartu Stok'));
    await tester.pumpAndSettle();
    await openAndBack('Buka Detail Kartu Stok (contoh)', 'BRG-0001');
    await openAndBack('Buka Label QR', 'Label QR BRG-0001');
    await back();
    await back();

    await tester.tap(tab('Riwayat'));
    await tester.pumpAndSettle();
    await openAndBack('Buka Detail Riwayat (contoh)', 'TRX-RCV-261007-0001');
    await back();
    expect(tester.takeException(), isNull);
  });
}
