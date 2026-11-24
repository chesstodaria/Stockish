import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockisi/data/mock/mock_seed.dart';
import 'package:stockisi/screens/documents/scanner_screen.dart';

import 'helpers.dart';

void main() {
  // Memakai peluncur scanner asli (bukan scanner palsu), untuk menangkap
  // kesalahan routing seperti cast Route<dynamic> ke Route<ScanOutcome?>.
  testWidgets('Scan QR membuka layar scanner asli dan bisa ke input manual',
      (tester) async {
    await pumpSignedIn(tester, realScanner: true);
    await openDocument(tester, MockDoc.rcvNew);
    await tester.tap(find.text('Scan QR'));
    await tester.pump();
    // Transisi halaman sekarang memakai CupertinoPageRoute (~500 ms),
    // jadi tunggu lebih lama daripada MaterialPageRoute sebelumnya.
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
    expect(find.byType(ScannerScreen), findsOneWidget);
    expect(find.text('Scan QR barang'), findsOneWidget);

    await tester.tap(
        find.widgetWithText(OutlinedButton, 'Input manual').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(ScannerScreen), findsNothing);
    expect(find.text('Kode barang'), findsOneWidget);
  });
}
