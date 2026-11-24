import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockisi/app.dart';
import 'package:stockisi/data/mock/mock_repositories.dart';
import 'package:stockisi/data/mock/mock_seed.dart';
import 'package:stockisi/data/repositories/repositories.dart';
import 'package:stockisi/data/repository_exceptions.dart';
import 'package:stockisi/screens/history/history_list_screen.dart';
import 'package:stockisi/screens/stock/stock_card_list_screen.dart';
import 'package:stockisi/services/qr_payload.dart';
import 'package:stockisi/services/scan_launcher.dart';

import 'helpers.dart';

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
  group('repository', () {
    late Repositories repo;

    setUp(() async {
      final backend = createSeededBackend(latency: Duration.zero);
      repo = createMockRepositories(backend);
      await repo.auth.login(MockNik.budi, kMockPassword);
    });

    test('riwayat hanya berisi transaksi gudang operator, terbaru dulu',
        () async {
      final history = await repo.transactions.getHistory();

      expect(history, isNotEmpty);
      expect(history.every((t) => t.warehouseCode == 'WH01'), isTrue);
      for (var i = 1; i < history.length; i++) {
        expect(
          history[i - 1].submittedAt.isAfter(history[i].submittedAt) ||
              history[i - 1].submittedAt.isAtSameMomentAs(
                  history[i].submittedAt),
          isTrue,
          reason: 'riwayat harus urut terbaru dulu',
        );
      }
    });

    test('detail transaksi gudang lain ditolak sebagai tidak ditemukan',
        () async {
      final otherBackend = createSeededBackend(latency: Duration.zero);
      final other = createMockRepositories(otherBackend);
      await other.auth.login('220118', kMockPassword); // Siti, WH02
      final wh02 = await other.transactions.getHistory();
      expect(wh02, isNotEmpty);

      expect(
        () => repo.transactions.getTransaction(wh02.first.number),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('pencarian kartu stok mengabaikan huruf besar-kecil', () async {
      final hasil = await repo.stockCard.searchItems('bearing');

      expect(hasil, isNotEmpty);
      expect(
        hasil.every((i) => i.warehouseCode == 'WH01'),
        isTrue,
        reason: 'barang gudang lain tidak boleh ikut',
      );
      expect(hasil.any((i) => i.itemCode == 'BRG-0012'), isTrue);
    });

    test('mutasi terbaru berakhir di saldo barang saat ini', () async {
      const kode = 'BRG-0001';
      final item = await repo.stockCard.getItem(kode);
      final movements = await repo.stockCard.getMovements(kode);

      expect(movements, isNotEmpty);
      expect(movements.first.balanceAfter, item.balance);
      for (var i = 1; i < movements.length; i++) {
        expect(
          movements[i - 1].date.isAfter(movements[i].date) ||
              movements[i - 1].date.isAtSameMomentAs(movements[i].date),
          isTrue,
          reason: 'mutasi harus urut terbaru dulu',
        );
      }
    });

    test('payload QR memakai kode|satuan|gudang dan bisa dibaca balik',
        () async {
      final item = await repo.stockCard.getItem('BRG-0001');
      final encoded = QrPayload(
        itemCode: item.itemCode,
        uom: item.uom,
        warehouseCode: item.warehouseCode,
      ).encode();

      expect(encoded.split(QrPayload.separator).length, 3);
      final parsed = QrPayload.tryParse(encoded);
      expect(parsed, isNotNull);
      expect(parsed!.itemCode, item.itemCode);
      expect(parsed.uom, item.uom);
      expect(parsed.warehouseCode, item.warehouseCode);
    });
  });

  group('widget', () {
    Finder inStock(Finder matching) => find.descendant(
        of: find.byType(StockCardListScreen), matching: matching);

    Finder inHistory(Finder matching) => find.descendant(
        of: find.byType(HistoryListScreen), matching: matching);

    testWidgets('tab Kartu Stok menampilkan barang dan menyaring pencarian',
        (tester) async {
      await enterHome(tester);
      await tester.tap(tab('Kartu Stok'));
      await tester.pumpAndSettle();

      expect(inStock(find.textContaining('BRG-0001')).hitTestable(), findsOneWidget);

      await tester.enterText(inStock(find.byType(TextField)), 'bearing');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(inStock(find.textContaining('BRG-0012')).hitTestable(), findsOneWidget);
      expect(inStock(find.textContaining('BRG-0001')).hitTestable(), findsNothing);
    });

    testWidgets('pencarian tanpa hasil menampilkan state kosong',
        (tester) async {
      await enterHome(tester);
      await tester.tap(tab('Kartu Stok'));
      await tester.pumpAndSettle();

      await tester.enterText(
          inStock(find.byType(TextField)), 'zzz-tidak-ada');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(inStock(find.text('Barang tidak ditemukan')).hitTestable(),
          findsOneWidget);
      expect(inStock(find.text('Hapus pencarian')).hitTestable(),
          findsOneWidget);
    });

    testWidgets('tab Riwayat menampilkan transaksi dan bisa dibuka',
        (tester) async {
      await enterHome(tester);
      await tester.tap(tab('Riwayat'));
      await tester.pumpAndSettle();

      expect(inHistory(find.textContaining('TRX-')).hitTestable(),
          findsWidgets);

      await tester.tap(inHistory(find.byType(Card)).hitTestable().first);
      await tester.pumpAndSettle();

      expect(find.text('Detail Riwayat').hitTestable(), findsOneWidget);
      expect(find.text('Waktu submit').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Label QR dibuka dari Detail Kartu Stok', (tester) async {
      await enterHome(tester);
      await tester.tap(tab('Kartu Stok'));
      await tester.pumpAndSettle();

      await tester.tap(inStock(find.textContaining('BRG-0001')).hitTestable());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Label QR').hitTestable());
      await tester.pumpAndSettle();

      // Isi QR ditulis apa adanya di layar supaya bisa dicek tanpa memindai.
      expect(find.textContaining('BRG-0001|').hitTestable(), findsOneWidget);
      expect(find.textContaining('|WH01').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // Syarat "Selesai kalau" Tahap 4: QR hasil Label QR bisa dipakai untuk
    // input barang di Detail Transaksi.
    testWidgets('isi QR dari Label QR diterima scanner di Detail Transaksi',
        (tester) async {
      final scanner = FakeScanner();
      await pumpSignedIn(tester, scanner: scanner);

      // 1. Ambil isi QR dari layar Label QR.
      await tapAndSettle(tester, navTab('Kartu Stok'));
      await tapAndSettle(tester, find.textContaining('BRG-0001'));
      await tapAndSettle(tester, find.text('Label QR'));

      final payloadFinder = find.textContaining('BRG-0001|');
      expect(payloadFinder, findsOneWidget);
      final payload = tester.widget<Text>(payloadFinder).data!;
      final parsed = QrPayload.tryParse(payload);
      expect(parsed, isNotNull, reason: 'isi QR harus 3 bagian');
      expect(tester.takeException(), isNull, reason: 'layar Label QR');

      // 2. Kembali ke Dokumen dan buka dokumen yang memuat barang itu.
      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, navTab('Dokumen'));
      await openDocument(tester, MockDoc.rcvNew);

      // 3. Pindai isi QR tadi seperti hasil kamera.
      scanner.queue.add(ScannedCode(payload));
      await tapAndSettle(tester, find.text('Scan QR'));

      expect(find.text('Scan ditolak'), findsNothing);
      expect(find.text('Tambah'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'lembar tambah jumlah');

      await tapAndSettle(tester, find.text('Tambah'));
      expect(find.textContaining('Total 60/60'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
