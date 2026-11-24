import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockisi/data/mock/mock_backend.dart';
import 'package:stockisi/data/mock/mock_seed.dart';

import 'helpers.dart';

/// Catatan desain: tab Dokumen sekarang menampilkan dua kelompok sekaligus,
/// "Perlu diproses" dan "Selesai". Jadi dokumen SUBMITTED tidak lagi hilang
/// dari daftar, ia hanya pindah kelompok.
void main() {
  testWidgets('default: dua kelompok, hanya gudang dan jenis sendiri',
      (tester) async {
    await pumpSignedIn(tester);
    expect(find.text(MockDoc.rcvNew), findsOneWidget);
    expect(find.text(MockDoc.rcvPartial), findsOneWidget);
    expect(find.textContaining('PERLU DIPROSES'), findsOneWidget);
    expect(find.text(MockDoc.otherWarehouseRcv), findsNothing); // WH02
    expect(find.text(MockDoc.intWithDraft), findsNothing); // INT
  });

  testWidgets('progres Partial dan penanda draf tampil', (tester) async {
    await pumpSignedIn(tester);
    expect(find.text('3 dari 5 item terpenuhi'), findsOneWidget);
    expect(find.text('Ada draf'), findsOneWidget);
    await tapAndSettle(tester, find.text('INT · Intransit'));
    expect(find.text(MockDoc.intWithDraft), findsOneWidget);
    expect(find.text('2 dari 4 item terpenuhi'), findsOneWidget);
    expect(find.text('Ada draf'), findsOneWidget);
    expect(find.text(MockDoc.rcvNew), findsNothing);
  });

  testWidgets('pencarian tanpa hasil memberi jalan kembali', (tester) async {
    await pumpSignedIn(tester);
    await tester.enterText(find.byType(TextField), 'tidak-ada');
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada dokumen yang cocok'), findsOneWidget);
    await tapAndSettle(tester, find.text('Hapus pencarian'));
    expect(find.text(MockDoc.rcvNew), findsOneWidget);
    await tester.scrollUntilVisible(find.text('PO-2610-0031'), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('PO-2610-0031'), findsOneWidget);
  });

  testWidgets('pencarian nomor dan vendor', (tester) async {
    await pumpSignedIn(tester);
    await tester.enterText(find.byType(TextField), '0046');
    await tester.pumpAndSettle();
    expect(find.text(MockDoc.rcvContested), findsOneWidget);
    expect(find.text(MockDoc.rcvNew), findsNothing);
    await tester.enterText(find.byType(TextField), 'baja prima');
    await tester.pumpAndSettle();
    expect(find.text(MockDoc.rcvNew), findsOneWidget);
    expect(find.text(MockDoc.rcvContested), findsNothing);
  });

  testWidgets('dokumen SUBMITTED tampil di bagian Selesai dan tidak bisa dibuka',
      (tester) async {
    await pumpSignedIn(tester);
    await tester.scrollUntilVisible(find.text('PO-2610-0031'), 200,
        scrollable: find.byType(Scrollable).last);
    await tapAndSettle(tester, find.text('PO-2610-0031'));
    expect(find.text('PO-2610-0031 sudah selesai dan tidak bisa diproses lagi.'),
        findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('gagal memuat lalu Coba lagi', (tester) async {
    await pumpSignedIn(tester, failOnce: {MockArea.documents});
    expect(find.text('Gagal memuat dokumen'), findsOneWidget);
    await tapAndSettle(tester, find.text('Coba lagi'));
    expect(find.text(MockDoc.rcvNew), findsOneWidget);
  });

  testWidgets('hanya dokumen gudang operator yang tampil', (tester) async {
    await pumpSignedIn(tester, nik: MockNik.siti);
    await tester.scrollUntilVisible(find.text('PO-2611-0049'), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('PO-2611-0049'), findsOneWidget);
    expect(find.text('PO-2610-0031'), findsNothing); // milik WH01
  });
}
