import 'package:flutter_test/flutter_test.dart';
import 'package:stockisi/data/transaction_rules.dart';
import 'package:stockisi/models/document_type.dart';
import 'package:stockisi/models/draft.dart';
import 'package:stockisi/models/reference_document.dart';

ReferenceDocumentItem item(String code,
        {int ordered = 10, int processed = 0, int? stock}) =>
    ReferenceDocumentItem(
      itemCode: code,
      itemName: 'Barang $code',
      uom: 'PCS',
      rackNumber: 'A-01-01',
      orderedQuantity: ordered,
      processedQuantity: processed,
      availableStock: stock,
    );

ReferenceDocument doc(DocumentType type, List<ReferenceDocumentItem> items) =>
    ReferenceDocument(
      number: 'X',
      type: type,
      warehouseCode: 'WH01',
      documentDate: DateTime(2026, 11, 1),
      counterparty: 'Vendor',
      status: DocumentStatus.open,
      version: 0,
      items: items,
    );

DraftLine line(String code, int qty, {bool unavailable = false}) =>
    DraftLine(itemCode: code, quantity: qty, markedUnavailable: unavailable);

void main() {
  group('itemStatusOf', () {
    test('tanpa input adalah Pending', () {
      expect(itemStatusOf(item('A'), null), ItemStatus.pending);
    });
    test('input di bawah sisa adalah Partial', () {
      expect(itemStatusOf(item('A'), line('A', 4)), ItemStatus.partial);
    });
    test('input sama dengan sisa adalah Complete', () {
      expect(itemStatusOf(item('A', processed: 6), line('A', 4)),
          ItemStatus.complete);
    });
    test('ditandai Tidak tersedia adalah Partial', () {
      expect(itemStatusOf(item('A'), line('A', 0, unavailable: true)),
          ItemStatus.partial);
    });
    test('sisa 0 sejak awal adalah Sudah terpenuhi', () {
      expect(itemStatusOf(item('A', processed: 10), null),
          ItemStatus.fulfilled);
    });
  });

  group('checkQuantity', () {
    test('menolak 0 dan negatif', () {
      expect(checkQuantity(item('A'), 0)!.problem, QuantityProblem.notPositive);
      expect(
          checkQuantity(item('A'), -2)!.problem, QuantityProblem.notPositive);
    });
    test('menolak melebihi sisa dan menyebut batasnya', () {
      final v = checkQuantity(item('A', processed: 3), 8)!;
      expect(v.problem, QuantityProblem.exceedsRemaining);
      expect(v.limit, 7);
      expect(v.message, contains('7 PCS'));
    });
    test('INT menolak melebihi stok', () {
      final v = checkQuantity(item('A', stock: 4), 5)!;
      expect(v.problem, QuantityProblem.exceedsStock);
      expect(v.limit, 4);
    });
    test('menerima nilai dalam batas', () {
      expect(checkQuantity(item('A', stock: 20), 10), isNull);
    });
  });

  group('checkSubmit', () {
    test('ditolak selama ada Pending', () {
      final d = doc(DocumentType.intransit, [item('A'), item('B')]);
      final c = checkSubmit(document: d, lines: {'A': line('A', 10)})!;
      expect(c.problem, SubmitProblem.pendingItems);
      expect(c.pendingCount, 1);
    });
    test('RCV wajib nomor surat jalan', () {
      final d = doc(DocumentType.receiving, [item('A')]);
      final c = checkSubmit(
          document: d, lines: {'A': line('A', 10)}, vendorDeliveryNo: '  ');
      expect(c!.problem, SubmitProblem.missingDeliveryNo);
    });
    test('item Sudah terpenuhi tidak dihitung Pending', () {
      final d = doc(
          DocumentType.intransit, [item('A'), item('B', processed: 10)]);
      expect(checkSubmit(document: d, lines: {'A': line('A', 10)}), isNull);
    });
    test('item Tidak tersedia boleh disubmit dan dihitung Partial', () {
      final d = doc(DocumentType.intransit, [item('A'), item('B')]);
      final lines = {
        'A': line('A', 10),
        'B': line('B', 0, unavailable: true),
      };
      expect(checkSubmit(document: d, lines: lines), isNull);
      expect(partialCountOf(d, lines), 1);
    });
  });
}
