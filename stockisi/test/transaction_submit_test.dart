import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockisi/data/mock/mock_backend.dart';
import 'package:stockisi/data/mock/mock_seed.dart';
import 'package:stockisi/models/document_type.dart';
import 'package:stockisi/widgets/item_status_chip.dart';
import 'package:stockisi/widgets/transaction_item_card.dart';

import 'helpers.dart';

Finder cardOf(String itemName) => find.ancestor(
    of: find.text(itemName), matching: find.byType(TransactionItemCard));

Finder chipIn(String itemName, String label) => find.descendant(
    of: cardOf(itemName),
    matching: find.descendant(
        of: find.byType(ItemStatusChip), matching: find.text(label)));

Future<void> manualAdd(WidgetTester tester, String code, int qty) async {
  await tapAndSettle(tester, find.text('Input manual'));
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), code);
  await tester.enterText(fields.at(1), '$qty');
  await tapAndSettle(tester, find.text('Tambah'));
}

Future<void> tapCard(WidgetTester tester, String itemName) async {
  await tester.scrollUntilVisible(find.text(itemName), 200,
      scrollable: find.byType(Scrollable).last);
  await tapAndSettle(tester, cardOf(itemName));
}

Future<void> markUnavailable(WidgetTester tester, String itemName) async {
  await tapCard(tester, itemName);
  await tapAndSettle(tester, find.text('Tandai tidak tersedia'));
}

Future<void> openSummary(WidgetTester tester) =>
    tapAndSettle(tester, find.text('Ringkasan'));

Future<void> tapSubmit(WidgetTester tester) =>
    tapAndSettle(tester, find.widgetWithText(FilledButton, 'Submit').first);

const cat = 'Cat Dasar Epoxy Abu-abu 20 L';
const resin = 'Resin Polypropylene Homopolimer 25 kg';

void main() {
  testWidgets('RCV lengkap: surat jalan wajib, submit, stok dan riwayat',
      (tester) async {
    final backend = await pumpSignedIn(tester);
    final catBefore = backend.balances['BRG-0004']!;
    final trxBefore = backend.transactions.length;

    await openDocument(tester, MockDoc.rcvSmall);
    await manualAdd(tester, 'BRG-0004', 12);
    await manualAdd(tester, 'BRG-0005', 20);
    await manualAdd(tester, 'BRG-0015', 80);
    expect(find.text('3 dari 3'), findsOneWidget);
    await openSummary(tester);

    await tapSubmit(tester);
    expect(find.text('Nomor surat jalan vendor wajib diisi.'), findsOneWidget);
    expect(find.text('Submit transaksi?'), findsNothing);

    await tester.enterText(find.byType(TextField), 'SIS/DO/2611/1104');
    await tapSubmit(tester);
    expect(find.text('Submit transaksi?'), findsOneWidget);
    await tapAndSettle(
        tester, find.descendant(of: find.byType(AlertDialog), matching: find.text('Submit')));

    expect(find.text('Transaksi berhasil disubmit'), findsOneWidget);
    expect(find.text('Dokumen ${MockDoc.rcvSmall} selesai.'), findsOneWidget);
    final trx = backend.transactions.last;
    expect(find.text(trx.number), findsOneWidget);
    await tapAndSettle(tester, find.text('Kembali ke daftar dokumen'));

    expect(find.text('RCV · Receiving'), findsOneWidget);
    expect(find.text(MockDoc.rcvSmall), findsNothing); // tidak lagi Terbuka
    expect(backend.balances['BRG-0004'], catBefore + 12);
    expect(backend.movementsByItem['BRG-0004']!.last.transactionNumber,
        trx.number);
    expect(backend.transactions.length, trxBefore + 1);
    expect(trx.vendorDeliveryNo, 'SIS/DO/2611/1104');
    expect(backend.documents[MockDoc.rcvSmall]!.status,
        DocumentStatus.submitted);
  });

  testWidgets(
      'RCV satu barang tidak datang: tanda dibatalkan kembali Pending, '
      'lalu disubmit sebagai Partial', (tester) async {
    final backend = await pumpSignedIn(tester);
    final resinBefore = backend.balances['BRG-0015']!;

    await openDocument(tester, MockDoc.rcvSmall);
    await manualAdd(tester, 'BRG-0004', 12);
    await manualAdd(tester, 'BRG-0005', 20);

    // Tandai, batalkan, item kembali Pending dan submit tertahan.
    await markUnavailable(tester, resin);
    expect(chipIn(resin, 'Partial'), findsOneWidget);
    await tapCard(tester, resin);
    await tapAndSettle(tester, find.text('Batalkan tanda Tidak tersedia'));
    expect(chipIn(resin, 'Pending'), findsOneWidget);
    await openSummary(tester);
    expect(find.textContaining('Masih ada 1 item Pending'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'SIS/DO/2611/1105');
    await tapSubmit(tester);
    expect(find.text('Masih ada 1 item Pending. Periksa semua item dulu.'),
        findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();

    // Tandai lagi lalu submit sebagai Partial.
    await markUnavailable(tester, resin);
    await openSummary(tester);
    expect(find.text('Tidak tersedia'), findsOneWidget);
    await tapSubmit(tester);
    expect(find.text('Ada 1 item Partial'), findsOneWidget);
    await tapAndSettle(
        tester, find.widgetWithText(OutlinedButton, 'Simpan sebagai Partial'));
    expect(find.text('Dokumen ${MockDoc.rcvSmall} tetap terbuka untuk sisa '
        'barang.'), findsOneWidget);
    await tapAndSettle(tester, find.text('Kembali ke daftar dokumen'));

    expect(find.text('Partial: 2 dari 3 item terpenuhi'), findsOneWidget);
    expect(backend.balances['BRG-0015'], resinBefore);
    final line = backend.transactions.last.lines
        .firstWhere((l) => l.itemCode == 'BRG-0015');
    expect((line.quantity, line.markedUnavailable), (0, true));
    expect(backend.documents[MockDoc.rcvSmall]!.status, DocumentStatus.open);

    // Dibuka lagi: hanya resin yang tersisa.
    await openDocument(tester, MockDoc.rcvSmall);
    expect(find.text('0 dari 1'), findsOneWidget);
  });

  testWidgets('INT Tandai Selesai dengan kekurangan stok', (tester) async {
    final backend = await pumpSignedIn(tester);
    await openDocument(tester, MockDoc.intStockLimit, intransit: true);
    await manualAdd(tester, 'BRG-0004', 6);
    await manualAdd(tester, 'BRG-0005', 10);
    await manualAdd(tester, 'BRG-0007', 10);
    expect(find.text('Melebihi stok tersedia. Maksimal 4 TBG.'),
        findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), '4');
    await tapAndSettle(tester, find.text('Tambah'));
    await manualAdd(tester, 'BRG-0011', 40);
    await openSummary(tester);
    expect(find.text('Nomor surat jalan vendor'), findsNothing);
    await tapSubmit(tester);
    expect(find.text('Ada 1 item Partial'), findsOneWidget);
    await tapAndSettle(
        tester, find.widgetWithText(FilledButton, 'Tandai Selesai'));
    expect(find.text('Dokumen ${MockDoc.intStockLimit} selesai.'),
        findsOneWidget);
    await tapAndSettle(tester, find.text('Kembali ke daftar dokumen'));

    expect(backend.balances['BRG-0007'], 0);
    expect(backend.movementsByItem['BRG-0007']!.last.type,
        DocumentType.intransit);
    expect(backend.documents[MockDoc.intStockLimit]!.status,
        DocumentStatus.submitted);
    expect(backend.transactions.last.type, DocumentType.intransit);
    expect(find.text(MockDoc.intStockLimit), findsNothing);
  });

  testWidgets('dokumen sudah diproses operator lain saat submit',
      (tester) async {
    final backend = await pumpSignedIn(tester);
    await openDocument(tester, MockDoc.rcvContested);
    await manualAdd(tester, 'BRG-0002', 1000);
    await manualAdd(tester, 'BRG-0003', 1000);
    await manualAdd(tester, 'BRG-0012', 24);
    await openSummary(tester);
    await tester.enterText(find.byType(TextField), 'SJ-STA-2611-201');
    await tapSubmit(tester);
    await tapAndSettle(tester,
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Submit')));

    expect(find.text('Dokumen sudah diproses operator lain'), findsOneWidget);
    expect(find.textContaining('sudah diselesaikan operator lain'),
        findsOneWidget);
    await tapAndSettle(tester, find.text('Kembali ke daftar dokumen'));
    expect(find.text('RCV · Receiving'), findsOneWidget);
    expect(find.text(MockDoc.rcvContested), findsNothing);
    expect(backend.transactions.last.operatorNik, MockNik.rina);
    expect(backend.draftsOf(MockNik.budi)[MockDoc.rcvContested], isNull);
  });

  testWidgets('gagal koneksi saat submit: pesan, input tetap, coba lagi',
      (tester) async {
    final backend = await pumpSignedIn(tester);
    await openDocument(tester, MockDoc.intWithDraft, intransit: true);
    // Draf: plat 20 dan baut 150 dari 200. Lengkapi sisanya.
    await tapCard(tester, 'Baut Hex M10x30 Galvanis');
    await tester.enterText(find.byType(TextField), '200');
    await tapAndSettle(tester, find.text('Simpan jumlah'));
    await manualAdd(tester, 'BRG-0010', 16);
    await manualAdd(tester, 'BRG-0003', 200);
    await manualAdd(tester, 'BRG-0006', 4);
    await openSummary(tester);

    backend.failNext(MockArea.submit);
    await tapSubmit(tester);
    await tapAndSettle(tester,
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Submit')));
    expect(find.textContaining('Submit gagal.'), findsOneWidget);
    expect(find.text('Transaksi berhasil disubmit'), findsNothing);

    await tapSubmit(tester);
    await tapAndSettle(tester,
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Submit')));
    expect(find.text('Transaksi berhasil disubmit'), findsOneWidget);
    await tapAndSettle(tester, find.text('Kembali ke daftar dokumen'));
    expect(find.text('INT · Intransit'), findsOneWidget);
    expect(backend.draftsOf(MockNik.budi)[MockDoc.intWithDraft], isNull);
  });
}
