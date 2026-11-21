import 'package:flutter_test/flutter_test.dart';
import 'package:stockisi/data/mock/mock_backend.dart';
import 'package:stockisi/data/mock/mock_repositories.dart';
import 'package:stockisi/data/mock/mock_seed.dart';
import 'package:stockisi/data/repositories/repositories.dart';
import 'package:stockisi/data/transaction_rules.dart';
import 'package:stockisi/viewmodels/transaction_view_model.dart';

void main() {
  late MockBackend backend;
  late Repositories repo;

  Future<TransactionViewModel> open(String number) async {
    final vm = TransactionViewModel(
      documentNumber: number,
      warehouseCode: 'WH01',
      documents: repo.documents,
      drafts: repo.drafts,
      transactions: repo.transactions,
    );
    await vm.load();
    return vm;
  }

  setUp(() async {
    backend = createSeededBackend(latency: Duration.zero);
    repo = createMockRepositories(backend);
    await repo.auth.login(MockNik.budi, kMockPassword);
  });

  group('memuat', () {
    test('dokumen baru siap tanpa input', () async {
      final vm = await open(MockDoc.rcvNew);
      expect(vm.state, TransactionLoadState.ready);
      expect(vm.resumedFromDraft, isFalse);
      expect(vm.checkedCount, 0);
      expect(vm.processableItems, hasLength(4));
    });

    test('draf yang masih berlaku dilanjutkan', () async {
      final vm = await open(MockDoc.intWithDraft);
      expect(vm.state, TransactionLoadState.ready);
      expect(vm.resumedFromDraft, isTrue);
      expect(vm.lineOf('BRG-0001')!.quantity, 20);
      expect(vm.lineOf('BRG-0002')!.quantity, 150);
      expect(vm.isDirty, isFalse);
    });

    test('draf untuk dokumen yang sudah berubah dibuang', () async {
      final vm = await open(MockDoc.rcvPartial);
      expect(vm.state, TransactionLoadState.staleDraft);
      expect(await repo.drafts.getDraft(MockDoc.rcvPartial), isNull);
    });

    test('dokumen SUBMITTED tidak bisa diproses', () async {
      final vm = await open('PO-2610-0031');
      expect(vm.state, TransactionLoadState.alreadySubmitted);
    });

    test('dokumen gudang lain tidak ditemukan', () async {
      final vm = await open(MockDoc.otherWarehouseRcv);
      expect(vm.state, TransactionLoadState.notFound);
    });

    test('gagal koneksi bisa dicoba lagi', () async {
      backend.failNext(MockArea.documents);
      final vm = await open(MockDoc.rcvNew);
      expect(vm.state, TransactionLoadState.error);
      await vm.load();
      expect(vm.state, TransactionLoadState.ready);
    });
  });

  group('scan', () {
    test('QR valid cocok, tidak peka huruf dan spasi', () async {
      final vm = await open(MockDoc.rcvNew);
      expect(vm.lookupScan(' brg-0001 | lbr | wh01 ').item?.itemCode,
          'BRG-0001');
    });

    test('format salah ditolak', () async {
      final vm = await open(MockDoc.rcvNew);
      for (final raw in ['BRG-0001', 'BRG-0001|LBR', 'a|b|c|d', '||', '']) {
        expect(vm.lookupScan(raw).error, contains('QR tidak dikenali'),
            reason: raw);
      }
    });

    test('barang milik gudang lain ditolak', () async {
      final vm = await open(MockDoc.rcvNew);
      expect(vm.lookupScan('BRG-0101|UNIT|WH02').error,
          contains('milik gudang WH02'));
    });

    test('barang yang tidak ada di dokumen ditolak', () async {
      final vm = await open(MockDoc.rcvNew);
      expect(vm.lookupScan('BRG-0012|PCS|WH01').error,
          'Barang BRG-0012 tidak ada di dokumen ${MockDoc.rcvNew}.');
    });

    test('satuan berbeda ditolak', () async {
      final vm = await open(MockDoc.rcvNew);
      expect(vm.lookupScan('BRG-0001|PCS|WH01').error,
          contains('Satuan di label (PCS)'));
    });

    test('item yang sudah terpenuhi ditolak', () async {
      final vm = await open(MockDoc.intPartial);
      expect(vm.lookupScan('BRG-0002|PCS|WH01').error,
          contains('sudah terpenuhi'));
    });

    test('input manual: kode kosong dan kode tidak dikenal', () async {
      final vm = await open(MockDoc.rcvNew);
      expect(vm.lookupManual('  ').error, 'Kode barang wajib diisi.');
      expect(vm.lookupManual('brg-0010').item?.itemCode, 'BRG-0010');
      expect(vm.lookupManual('XYZ').error, contains('tidak ada di dokumen'));
    });
  });

  group('kuantitas dan status', () {
    test('scan/manual menambah, ubah dari kartu mengganti', () async {
      final vm = await open(MockDoc.rcvNew);
      final plat = vm.items.firstWhere((i) => i.itemCode == 'BRG-0001');
      expect(vm.addQuantity(plat, 20), isNull);
      expect(vm.addQuantity(plat, 15), isNull);
      expect(vm.lineOf('BRG-0001')!.quantity, 35);
      expect(vm.statusOf(plat), ItemStatus.partial);
      expect(vm.setQuantity(plat, 60), isNull);
      expect(vm.lineOf('BRG-0001')!.quantity, 60);
      expect(vm.statusOf(plat), ItemStatus.complete);
      expect(vm.isDirty, isTrue);
    });

    test('penambahan yang melewati sisa ditolak dan tidak mengubah apa pun',
        () async {
      final vm = await open(MockDoc.rcvNew);
      final plat = vm.items.firstWhere((i) => i.itemCode == 'BRG-0001');
      vm.addQuantity(plat, 50);
      expect(vm.addQuantity(plat, 11),
          'Melebihi sisa dokumen. Maksimal 60 LBR.');
      expect(vm.lineOf('BRG-0001')!.quantity, 50);
      expect(vm.addQuantity(plat, 0), 'Kuantitas harus lebih dari 0.');
    });

    test('INT dibatasi saldo stok', () async {
      final vm = await open(MockDoc.intStockLimit);
      final argon = vm.items.firstWhere((i) => i.itemCode == 'BRG-0007');
      expect(vm.addQuantity(argon, 5),
          'Melebihi stok tersedia. Maksimal 4 TBG.');
      expect(vm.addQuantity(argon, 4), isNull);
    });

    test('sisa dihitung dari transaksi Partial sebelumnya', () async {
      final vm = await open(MockDoc.intPartial);
      final bearing = vm.items.firstWhere((i) => i.itemCode == 'BRG-0012');
      expect(bearing.remainingQuantity, 8);
      expect(vm.addQuantity(bearing, 9), contains('Maksimal 8 PCS'));
      expect(vm.countOf(ItemStatus.fulfilled), 2);
      expect(vm.processableItems, hasLength(2));
    });

    test('tanda Tidak tersedia: Partial, bisa dibatalkan ke Pending',
        () async {
      final vm = await open(MockDoc.rcvNew);
      final gerinda = vm.items.firstWhere((i) => i.itemCode == 'BRG-0014');
      vm.markUnavailable(gerinda);
      expect(vm.statusOf(gerinda), ItemStatus.partial);
      expect(vm.lineOf('BRG-0014')!.markedUnavailable, isTrue);
      expect(vm.checkedCount, 1);
      vm.clearItem(gerinda);
      expect(vm.statusOf(gerinda), ItemStatus.pending);
      expect(vm.checkedCount, 0);
    });

    test('tanda hanya untuk item tanpa input; scan menimpa tanda', () async {
      final vm = await open(MockDoc.rcvNew);
      final plat = vm.items.firstWhere((i) => i.itemCode == 'BRG-0001');
      vm.addQuantity(plat, 10);
      vm.markUnavailable(plat);
      expect(vm.lineOf('BRG-0001')!.markedUnavailable, isFalse);
      vm.clearItem(plat);
      vm.markUnavailable(plat);
      vm.addQuantity(plat, 5);
      expect(vm.lineOf('BRG-0001')!.markedUnavailable, isFalse);
      expect(vm.lineOf('BRG-0001')!.quantity, 5);
    });

    test('hapus input mengembalikan Pending', () async {
      final vm = await open(MockDoc.rcvNew);
      final pipa = vm.items.firstWhere((i) => i.itemCode == 'BRG-0010');
      vm.addQuantity(pipa, 40);
      vm.clearItem(pipa);
      expect(vm.statusOf(pipa), ItemStatus.pending);
    });
  });

  group('draf', () {
    test('simpan draf lalu buka lagi', () async {
      var vm = await open(MockDoc.rcvNew);
      vm.addQuantity(vm.items.first, 10);
      vm.markUnavailable(vm.items[2]);
      await vm.saveDraft();
      expect(vm.isDirty, isFalse);
      vm = await open(MockDoc.rcvNew);
      expect(vm.resumedFromDraft, isTrue);
      expect(vm.lineOf(vm.items.first.itemCode)!.quantity, 10);
      expect(vm.lineOf(vm.items[2].itemCode)!.markedUnavailable, isTrue);
    });

    test('simpan dengan input kosong membuang draf lama', () async {
      final vm = await open(MockDoc.intWithDraft);
      for (final i in vm.items) {
        vm.clearItem(i);
      }
      await vm.saveDraft();
      expect(await repo.drafts.getDraft(MockDoc.intWithDraft), isNull);
    });

    test('buang draf', () async {
      final vm = await open(MockDoc.intWithDraft);
      vm.addQuantity(vm.items.last, 1);
      await vm.discardDraft();
      expect(await repo.drafts.getDraft(MockDoc.intWithDraft), isNull);
      expect(vm.lines, isEmpty);
      expect(vm.isDirty, isFalse);
    });
  });
}
