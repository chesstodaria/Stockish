import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockisi/app.dart';
import 'package:stockisi/services/device_id_store.dart';
import 'package:stockisi/data/mock/mock_backend.dart';
import 'package:stockisi/data/mock/mock_repositories.dart';
import 'package:stockisi/data/mock/mock_seed.dart';
import 'package:stockisi/services/session_store.dart';

/// Membuka app dengan backend baru tetapi [store] yang sama, meniru app
/// ditutup lalu dibuka lagi di perangkat yang sama.
Future<MockBackend> openApp(
  WidgetTester tester,
  SessionStore store, {
  Set<MockArea> failOnce = const {},
}) async {
  final backend =
      createSeededBackend(latency: Duration.zero, failOnce: failOnce);
  // Key baru memaksa seluruh pohon widget dibuat ulang.
  await tester.pumpWidget(StockisiApp(
    key: UniqueKey(),
    repositories: createMockRepositories(backend, sessionStore: store),
    deviceIds: DeviceIdStore.fixed('test-device'),
  ));
  await tester.pumpAndSettle();
  return backend;
}

Finder get nikField => find.widgetWithText(TextFormField, 'NIK');
Finder get passwordField => find.widgetWithText(TextFormField, 'Kata sandi');
Finder get loginButton => find.widgetWithText(FilledButton, 'Masuk');

Future<void> login(WidgetTester tester, String nik, String password) async {
  await tester.enterText(nikField, nik);
  await tester.enterText(passwordField, password);
  await tester.tap(loginButton);
  await tester.pumpAndSettle();
}

String fieldText(WidgetTester tester, Finder field) =>
    tester.widget<TextFormField>(field).controller!.text;

Future<void> openProfileAndTapLogout(WidgetTester tester) async {
  await tester.tap(find.descendant(
      of: find.byType(NavigationBar), matching: find.text('Profil')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Logout'));
  await tester.pumpAndSettle();
}

void main() {
  group('Masuk', () {
    testWidgets('tanpa sesi, Splash mengarah ke Login', (tester) async {
      await openApp(tester, InMemorySessionStore());
      expect(loginButton, findsOneWidget);
    });

    testWidgets('kolom kosong ditolak dengan pesan per kolom', (tester) async {
      await openApp(tester, InMemorySessionStore());
      await tester.tap(loginButton);
      await tester.pumpAndSettle();
      expect(find.text('NIK wajib diisi.'), findsOneWidget);
      expect(find.text('Kata sandi wajib diisi.'), findsOneWidget);
    });

    testWidgets('sandi salah: pesan muncul, NIK tetap, sandi dikosongkan',
        (tester) async {
      await openApp(tester, InMemorySessionStore());
      await login(tester, MockNik.budi, 'salah123');
      expect(find.text('NIK atau kata sandi salah.'), findsOneWidget);
      expect(fieldText(tester, nikField), MockNik.budi);
      expect(fieldText(tester, passwordField), isEmpty);
      expect(find.text('Kata sandi wajib diisi.'), findsNothing);
      final editable = tester.widget<EditableText>(find.descendant(
          of: passwordField, matching: find.byType(EditableText)));
      expect(editable.focusNode.hasFocus, isTrue);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('NIK tidak terdaftar memakai pesan yang sama', (tester) async {
      await openApp(tester, InMemorySessionStore());
      await login(tester, '999999', kMockPassword);
      expect(find.text('NIK atau kata sandi salah.'), findsOneWidget);
      expect(fieldText(tester, nikField), '999999');
    });

    testWidgets('akun nonaktif ditolak dengan pesan khusus', (tester) async {
      await openApp(tester, InMemorySessionStore());
      await login(tester, MockNik.agus, kMockPassword);
      expect(find.text('Akun Anda nonaktif. Hubungi admin gudang.'),
          findsOneWidget);
      expect(fieldText(tester, nikField), MockNik.agus);
    });

    testWidgets('pesan hilang saat operator mengetik lagi', (tester) async {
      await openApp(tester, InMemorySessionStore());
      await login(tester, MockNik.budi, 'salah123');
      await tester.enterText(passwordField, 's');
      await tester.pump();
      expect(find.text('NIK atau kata sandi salah.'), findsNothing);
    });

    testWidgets('gagal koneksi: pesan, isian tetap, coba lagi berhasil',
        (tester) async {
      await openApp(tester, InMemorySessionStore(),
          failOnce: {MockArea.login});
      await login(tester, MockNik.budi, kMockPassword);
      expect(find.textContaining('Periksa koneksi internet'), findsOneWidget);
      expect(fieldText(tester, passwordField), kMockPassword);
      await tester.tap(loginButton);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('berhasil masuk ke tab Dokumen, tidak bisa kembali ke Login',
        (tester) async {
      await openApp(tester, InMemorySessionStore());
      await login(tester, MockNik.budi, kMockPassword);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('RCV · Receiving').hitTestable(), findsOneWidget);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isFalse);
    });

    testWidgets('app dibuka ulang langsung ke halaman utama', (tester) async {
      final store = InMemorySessionStore();
      await openApp(tester, store);
      await login(tester, MockNik.siti, kMockPassword);
      await openApp(tester, store);
      expect(loginButton, findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.descendant(
          of: find.byType(NavigationBar), matching: find.text('Profil')));
      await tester.pumpAndSettle();
      expect(find.text('Siti Rahmawati'), findsOneWidget);
      expect(find.textContaining('Gudang Barang Jadi Pasuruan'), findsOneWidget);
    });

    testWidgets('sesi akun yang kini nonaktif tidak dipulihkan',
        (tester) async {
      final store = InMemorySessionStore();
      await store.writeNik(MockNik.agus);
      await openApp(tester, store);
      expect(loginButton, findsOneWidget);
      expect(await store.readNik(), isNull);
    });
  });

  group('Penjaga sesi (link web)', () {
    NavigatorState nav(WidgetTester tester) =>
        tester.state<NavigatorState>(find.byType(Navigator));

    testWidgets('membuka halaman utama tanpa sesi berakhir di Login',
        (tester) async {
      await openApp(tester, InMemorySessionStore());
      nav(tester).pushNamed('/beranda');
      await tester.pumpAndSettle();
      expect(loginButton, findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(nav(tester).canPop(), isFalse);
    });

    testWidgets('layar turunan tanpa sesi juga berakhir di Login',
        (tester) async {
      await openApp(tester, InMemorySessionStore());
      nav(tester).pushNamed('/kartu-stok/detail', arguments: 'BRG-0001');
      await tester.pumpAndSettle();
      expect(loginButton, findsOneWidget);
    });

    testWidgets('link tanpa argumen diulang dari Splash, tidak crash',
        (tester) async {
      final store = InMemorySessionStore();
      await openApp(tester, store);
      await login(tester, MockNik.budi, kMockPassword);
      nav(tester).pushNamed('/dokumen/detail');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(nav(tester).canPop(), isFalse);
    });
  });

  group('Keluar', () {
    testWidgets('Profil menampilkan nama, NIK, dan gudang', (tester) async {
      await openApp(tester, InMemorySessionStore());
      await login(tester, MockNik.budi, kMockPassword);
      await tester.tap(find.descendant(
          of: find.byType(NavigationBar), matching: find.text('Profil')));
      await tester.pumpAndSettle();
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('NIK 210457'), findsOneWidget);
      expect(find.textContaining('Gudang Bahan Baku Sidoarjo'), findsOneWidget);
    });

    testWidgets('ada draf: operator diberi tahu, Batal tetap di Profil',
        (tester) async {
      await openApp(tester, InMemorySessionStore());
      await login(tester, MockNik.budi, kMockPassword);
      await openProfileAndTapLogout(tester);
      expect(find.text('Ada draf yang belum disubmit'), findsOneWidget);
      expect(find.text(MockDoc.intWithDraft), findsOneWidget);
      expect(find.text(MockDoc.rcvPartial), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(loginButton, findsNothing);
    });

    testWidgets('ada draf: Tetap logout kembali ke Login dan sesi terhapus',
        (tester) async {
      final store = InMemorySessionStore();
      await openApp(tester, store);
      await login(tester, MockNik.budi, kMockPassword);
      await openProfileAndTapLogout(tester);
      await tester.tap(find.text('Tetap logout'));
      await tester.pumpAndSettle();
      expect(loginButton, findsOneWidget);
      expect(await store.readNik(), isNull);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isFalse);
      await openApp(tester, store);
      expect(loginButton, findsOneWidget);
    });

    testWidgets('tanpa draf: konfirmasi biasa', (tester) async {
      await openApp(tester, InMemorySessionStore());
      await login(tester, MockNik.siti, kMockPassword);
      await openProfileAndTapLogout(tester);
      expect(find.text('Logout dari Stockisi?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
      await tester.pumpAndSettle();
      expect(loginButton, findsOneWidget);
    });

    testWidgets('draf gagal diperiksa: tetap bisa logout dengan keterangan',
        (tester) async {
      final backend = await openApp(tester, InMemorySessionStore());
      await login(tester, MockNik.budi, kMockPassword);
      backend.failNext(MockArea.drafts);
      await openProfileAndTapLogout(tester);
      expect(find.textContaining('Draf tidak bisa diperiksa'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
      await tester.pumpAndSettle();
      expect(loginButton, findsOneWidget);
    });
  });
}
