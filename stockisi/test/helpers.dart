import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockisi/app.dart';
import 'package:stockisi/data/mock/mock_backend.dart';
import 'package:stockisi/data/mock/mock_repositories.dart';
import 'package:stockisi/data/mock/mock_seed.dart';
import 'package:stockisi/screens/documents/scanner_screen.dart';
import 'package:stockisi/services/device_id_store.dart';
import 'package:stockisi/services/scan_launcher.dart';
import 'package:stockisi/services/session_store.dart';

/// Membuka dokumen dari tab Dokumen (menggulir kalau perlu).
Future<void> openDocument(WidgetTester tester, String number,
    {bool intransit = false}) async {
  if (intransit) await tapAndSettle(tester, find.text('INT · Intransit'));
  await tester.scrollUntilVisible(find.text(number), 200,
      scrollable: find.byType(Scrollable).last);
  await tapAndSettle(tester, find.text(number));
}

/// Membuka app di layar besar ala HP (390x844) dengan data tiruan tanpa
/// jeda, lalu login. Mengembalikan backend supaya test bisa memeriksa data.
/// Scanner palsu: mengembalikan hasil dari antrean, tanpa kamera.
class FakeScanner {
  final List<ScanOutcome?> queue = [];
  int launches = 0;

  Future<ScanOutcome?> call(BuildContext context) async {
    launches++;
    return queue.isEmpty ? null : queue.removeAt(0);
  }
}

Future<MockBackend> pumpSignedIn(
  WidgetTester tester, {
  String nik = MockNik.budi,
  Set<MockArea> failOnce = const {},
  FakeScanner? scanner,
  bool realScanner = false,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final backend =
      createSeededBackend(latency: Duration.zero, failOnce: failOnce);
  final store = InMemorySessionStore();
  await store.writeNik(nik);
  await tester.pumpWidget(StockisiApp(
    key: UniqueKey(),
    repositories: createMockRepositories(backend, sessionStore: store),
    scanLauncher: realScanner
        ? launchCameraScanner
        : (scanner?.call ?? FakeScanner().call),
    deviceIds: DeviceIdStore.fixed('test-device'),
  ));
  await tester.pumpAndSettle();
  return backend;
}

Finder navTab(String label) => find.descendant(
    of: find.byType(NavigationBar), matching: find.text(label));

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
