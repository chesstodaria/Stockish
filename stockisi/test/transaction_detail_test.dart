import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockisi/data/mock/mock_seed.dart';
import 'package:stockisi/services/scan_launcher.dart';
import 'package:stockisi/widgets/status_chip.dart';
import 'package:stockisi/widgets/transaction_item_card.dart';

import 'helpers.dart';

Finder cardOf(String itemName) => find.ancestor(
    of: find.text(itemName), matching: find.byType(TransactionItemCard));

Finder chipIn(String itemName, String label) => find.descendant(
    of: cardOf(itemName),
    matching: find.descendant(
        of: find.byType(StatusChip), matching: find.text(label)));

const plat = 'Plat Besi SPCC 1,2 mm 4x8 ft';
const gerinda = 'Mata Gerinda Potong 4 inci';

Future<void> tapKembali(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Kembali'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('detail menampilkan progres dan kartu item', (tester) async {
    await pumpSignedIn(tester);
    await openDocument(tester, MockDoc.rcvNew);
    expect(find.text('0 dari 4'), findsOneWidget);
    expect(find.text('Scan QR'), findsOneWidget);
    expect(chipIn(plat, 'Belum'), findsOneWidget);
  });

  testWidgets('scan valid lalu tambah jumlah', (tester) async {
    final scanner = FakeScanner()
      ..queue.add(const ScannedCode('BRG-0001|LBR|WH01'));
    await pumpSignedIn(tester, scanner: scanner);
    await openDocument(tester, MockDoc.rcvNew);
    await tapAndSettle(tester, find.text('Scan QR'));
    expect(find.text('Jumlah diterima (ditambahkan)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '25');
    await tapAndSettle(tester, find.text('Tambah'));
    expect(find.textContaining('+25 LBR'), findsOneWidget);
    expect(chipIn(plat, 'Parsial'), findsOneWidget);
    expect(find.text('1 dari 4'), findsOneWidget);
  });

  testWidgets('jumlah melebihi sisa ditolak dengan batasnya', (tester) async {
    final scanner = FakeScanner()
      ..queue.add(const ScannedCode('BRG-0001|LBR|WH01'));
    await pumpSignedIn(tester, scanner: scanner);
    await openDocument(tester, MockDoc.rcvNew);
    await tapAndSettle(tester, find.text('Scan QR'));
    await tester.enterText(find.byType(TextField), '61');
    await tapAndSettle(tester, find.text('Tambah'));
    expect(find.text('Melebihi sisa dokumen. Maksimal 60 LBR.'),
        findsOneWidget);
  });

  testWidgets('scan ditolak menawarkan Scan lagi dan Input manual',
      (tester) async {
    final scanner = FakeScanner()
      ..queue.addAll(const [
        ScannedCode('BRG-0101|UNIT|WH02'),
        ScannedCode('BUKAN-QR-STOCKISI'),
      ]);
    await pumpSignedIn(tester, scanner: scanner);
    await openDocument(tester, MockDoc.rcvNew);
    await tapAndSettle(tester, find.text('Scan QR'));
    expect(find.text('Scan ditolak'), findsOneWidget);
    expect(find.textContaining('milik gudang WH02'), findsOneWidget);
    await tapAndSettle(tester, find.text('Scan lagi'));
    expect(find.textContaining('QR tidak dikenali'), findsOneWidget);
    await tapAndSettle(tester, find.text('Input manual').last);
    expect(find.text('Kode barang'), findsOneWidget);
  });

  testWidgets('izin kamera ditolak mengarah ke input manual', (tester) async {
    final scanner = FakeScanner()
      ..queue.add(const CameraUnavailable(CameraProblem.permissionDenied));
    await pumpSignedIn(tester, scanner: scanner);
    await openDocument(tester, MockDoc.rcvNew);
    await tapAndSettle(tester, find.text('Scan QR'));
    expect(find.textContaining('Izin kamera ditolak'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Kode barang'), 'brg-0010');
    await tester.enterText(
        find.widgetWithText(TextField, 'Jumlah diterima (ditambahkan)'), '40');
    await tapAndSettle(tester, find.text('Tambah'));
    expect(chipIn('Pipa Hollow 40x40x2 mm 6 m', 'Selesai'), findsOneWidget);
  });

  testWidgets('input manual: kode tidak ada di dokumen', (tester) async {
    await pumpSignedIn(tester);
    await openDocument(tester, MockDoc.rcvNew);
    await tapAndSettle(tester, find.text('Input manual'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Kode barang'), 'BRG-0012');
    await tester.enterText(
        find.widgetWithText(TextField, 'Jumlah diterima (ditambahkan)'), '1');
    await tapAndSettle(tester, find.text('Tambah'));
    expect(find.text('Barang BRG-0012 tidak ada di dokumen ${MockDoc.rcvNew}.'),
        findsOneWidget);
  });

  testWidgets('tandai tidak tersedia lalu batalkan', (tester) async {
    await pumpSignedIn(tester);
    await openDocument(tester, MockDoc.rcvNew);
    await tapAndSettle(tester, cardOf(gerinda));
    await tapAndSettle(tester, find.text('Tandai tidak tersedia'));
    expect(chipIn(gerinda, 'Parsial'), findsOneWidget);
    expect(find.descendant(
        of: cardOf(gerinda), matching: find.text('Tidak tersedia')),
        findsOneWidget);
    await tapAndSettle(tester, cardOf(gerinda));
    await tapAndSettle(tester, find.text('Batalkan tanda Tidak tersedia'));
    expect(chipIn(gerinda, 'Belum'), findsOneWidget);
  });

  testWidgets('ubah jumlah mengganti, hapus input kembali Pending',
      (tester) async {
    await pumpSignedIn(tester);
    await openDocument(tester, MockDoc.rcvNew);
    await tapAndSettle(tester, cardOf(plat));
    await tester.enterText(find.byType(TextField), '60');
    await tapAndSettle(tester, find.text('Simpan jumlah'));
    expect(chipIn(plat, 'Selesai'), findsOneWidget);
    await tapAndSettle(tester, cardOf(plat));
    await tapAndSettle(tester, find.text('Hapus input'));
    expect(chipIn(plat, 'Belum'), findsOneWidget);
  });

  testWidgets('kembali tanpa input tidak bertanya', (tester) async {
    await pumpSignedIn(tester);
    await openDocument(tester, MockDoc.rcvNew);
    await tapKembali(tester);
    expect(find.text('RCV · Receiving'), findsOneWidget);
  });

  testWidgets('kembali dengan input: Batal, Simpan draf, lanjutkan',
      (tester) async {
    await pumpSignedIn(tester);
    await openDocument(tester, MockDoc.rcvNew);
    await tapAndSettle(tester, cardOf(gerinda));
    await tapAndSettle(tester, find.text('Tandai tidak tersedia'));

    await tapKembali(tester);
    expect(find.text('Keluar dari dokumen?'), findsOneWidget);
    await tapAndSettle(tester, find.text('Batal'));
    expect(find.text('0 dari 4'), findsNothing);
    expect(find.text('1 dari 4'), findsOneWidget);

    await tapKembali(tester);
    await tapAndSettle(tester, find.text('Simpan draf'));
    expect(find.text('RCV · Receiving'), findsOneWidget);
    expect(find.text('Ada draf'), findsNWidgets(2)); // PO-0041 dan PO-0043

    await openDocument(tester, MockDoc.rcvNew);
    expect(find.text('Melanjutkan draf ${MockDoc.rcvNew}.'), findsOneWidget);
    expect(chipIn(gerinda, 'Parsial'), findsOneWidget);
    // Tanpa perubahan baru, kembali tidak bertanya lagi.
    await tapKembali(tester);
    expect(find.text('Keluar dari dokumen?'), findsNothing);
  });

  testWidgets('kembali dengan input: Buang draf', (tester) async {
    await pumpSignedIn(tester);
    await openDocument(tester, MockDoc.intWithDraft, intransit: true);
    const kawat = 'Kawat Las ER70S-6 0,8 mm 15 kg';
    await tester.scrollUntilVisible(find.text(kawat), 200,
        scrollable: find.byType(Scrollable).last);
    await tapAndSettle(tester, cardOf(kawat));
    await tapAndSettle(tester, find.text('Tandai tidak tersedia'));
    await tapKembali(tester);
    await tapAndSettle(tester, find.text('Buang draf'));
    expect(find.text('INT · Intransit'), findsOneWidget);
    expect(find.text('Ada draf'), findsNothing);
  });

  testWidgets('draf untuk dokumen yang sudah berubah: pesan, draf dibuang',
      (tester) async {
    await pumpSignedIn(tester);
    await openDocument(tester, MockDoc.rcvPartial);
    expect(find.text('Dokumen sudah berubah'), findsOneWidget);
    await tapAndSettle(tester, find.text('Kembali ke daftar'));
    expect(find.text('RCV · Receiving'), findsOneWidget);
    expect(find.text('Ada draf'), findsNothing);
    // Dibuka lagi: mulai dari sisa terbaru, item terpenuhi tidak dihitung.
    await openDocument(tester, MockDoc.rcvPartial);
    expect(find.text('0 dari 2'), findsOneWidget);
  });
}
