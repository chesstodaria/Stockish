import 'package:flutter_test/flutter_test.dart';
import 'package:stockisi/data/mock/mock_seed.dart';
import 'package:stockisi/models/document_type.dart';

void main() {
  final backend = createSeededBackend(latency: Duration.zero);

  test('saldo setiap barang sama dengan jumlah mutasinya', () {
    for (final item in backend.items.values) {
      final moves = backend.movementsByItem[item.code] ?? const [];
      final sum = moves.fold<int>(0, (s, m) => s + m.signedQuantity);
      expect(backend.balances[item.code] ?? 0, sum, reason: item.code);
      expect(sum, greaterThanOrEqualTo(0), reason: item.code);
    }
  });

  test('saldo setelah tiap mutasi berurutan dan konsisten', () {
    for (final entry in backend.movementsByItem.entries) {
      var running = 0;
      final sorted = [...entry.value]..sort((a, b) => a.date.compareTo(b.date));
      for (final m in sorted) {
        running += m.signedQuantity;
        expect(m.balanceAfter, running, reason: entry.key);
      }
    }
  });

  test('barang di dokumen milik gudang yang sama dengan dokumennya', () {
    for (final doc in backend.documents.values) {
      for (final line in doc.lines) {
        expect(backend.items[line.itemCode]!.warehouseCode, doc.warehouseCode,
            reason: '${doc.number} ${line.itemCode}');
      }
    }
  });

  test('jumlah data sesuai rencana Tahap 1', () {
    expect(backend.warehouses.length, greaterThanOrEqualTo(2));
    expect(backend.accounts.values.where((a) => !a.profile.isActive),
        hasLength(1));
    final wh01Items =
        backend.items.values.where((i) => i.warehouseCode == 'WH01');
    expect(wh01Items.length, 15);
    expect(
        backend.documents.values.where((d) => d.warehouseCode == 'WH02'),
        isNotEmpty);
  });

  test('variasi status dokumen tersedia untuk RCV dan INT', () {
    for (final type in DocumentType.values) {
      final docs = backend.documents.values
          .where((d) => d.warehouseCode == 'WH01' && d.type == type)
          .map(backend.toDocument)
          .toList();
      expect(docs.where((d) => !d.isOpen), isNotEmpty, reason: '$type');
      expect(docs.where((d) => d.isOpen && !d.hasPartialProgress), isNotEmpty,
          reason: '$type');
      expect(docs.where((d) => d.hasPartialProgress), isNotEmpty,
          reason: '$type');
    }
  });

  test('progres Partial sesuai contoh di catatan', () {
    final rcv = backend.toDocument(backend.documents[MockDoc.rcvPartial]!);
    expect((rcv.fulfilledItemCount, rcv.itemCount), (3, 5));
    final intDoc = backend.toDocument(backend.documents[MockDoc.intPartial]!);
    expect((intDoc.fulfilledItemCount, intDoc.itemCount), (2, 4));
  });

  test('BON batas stok meminta argon melebihi saldo', () {
    final d = backend.toDocument(backend.documents[MockDoc.intStockLimit]!);
    final argon = d.items.firstWhere((i) => i.itemCode == 'BRG-0007');
    expect(argon.availableStock, 4);
    expect(argon.remainingQuantity, greaterThan(argon.availableStock!));
  });

  test('ada satu barang tanpa riwayat mutasi', () {
    expect(backend.movementsByItem['BRG-0014'], isNull);
    expect(backend.balances['BRG-0014'] ?? 0, 0);
  });
}
