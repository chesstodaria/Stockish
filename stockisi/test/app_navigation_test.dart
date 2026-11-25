import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockisi/app.dart';
import 'package:stockisi/services/device_id_store.dart';
import 'package:stockisi/data/mock/mock_repositories.dart';
import 'package:stockisi/data/mock/mock_seed.dart';

Future<void> enterHome(WidgetTester tester) async {
  final backend = createSeededBackend(latency: Duration.zero);
  await tester.pumpWidget(
      StockisiApp(repositories: createMockRepositories(backend), deviceIds: DeviceIdStore.fixed('test-device')));
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
    expect(find.text('RCV · Receiving'), findsOneWidget);
  });

  testWidgets('keempat tab bisa dibuka tanpa error', (tester) async {
    await enterHome(tester);

    await tester.tap(tab('Dokumen'));
    await tester.pumpAndSettle();
    expect(find.text('RCV · Receiving').hitTestable(), findsOneWidget);

    await tester.tap(tab('Kartu Stok'));
    await tester.pumpAndSettle();
    expect(find.textContaining('BRG-0001').hitTestable(), findsOneWidget);

    await tester.tap(tab('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.textContaining('TRX-').hitTestable(), findsWidgets);

    await tester.tap(tab('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Budi Santoso').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('routing ke layar turunan setiap tab', (tester) async {
    await enterHome(tester);

    // Tooltip tombol kembali sudah berbahasa Indonesia ("Kembali"), jadi
    // tester.pageBack() (mencari tooltip "Back") tidak dipakai.
    Future<void> back() async {
      await tester.tap(find.byTooltip('Kembali').hitTestable());
      await tester.pumpAndSettle();
    }

    await tester.tap(tab('Kartu Stok'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('BRG-0001').hitTestable());
    await tester.pumpAndSettle();
    expect(find.textContaining('RIWAYAT MUTASI').hitTestable(), findsOneWidget);

    await tester.tap(find.text('Label QR').hitTestable());
    await tester.pumpAndSettle();
    expect(find.textContaining('BRG-0001|').hitTestable(), findsOneWidget);
    await back();
    await back();

    await tester.tap(tab('Riwayat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Card).hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.text('Detail Riwayat').hitTestable(), findsOneWidget);
    await back();
    expect(tester.takeException(), isNull);
  });
}
