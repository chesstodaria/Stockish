import 'package:flutter_test/flutter_test.dart';
import 'package:stockisi/data/mock/mock_backend.dart';
import 'package:stockisi/data/mock/mock_repositories.dart';
import 'package:stockisi/data/mock/mock_seed.dart';
import 'package:stockisi/data/repositories/repositories.dart';
import 'package:stockisi/data/repository_exceptions.dart';
import 'package:stockisi/data/transaction_rules.dart';
import 'package:stockisi/models/document_type.dart';
import 'package:stockisi/models/draft.dart';

void main() {
  late MockBackend backend;
  late Repositories repo;

  Future<void> loginBudi() => repo.auth.login(MockNik.budi, kMockPassword);

  setUp(() {
    backend = createSeededBackend(latency: Duration.zero);
    repo = createMockRepositories(backend);
  });

  group('auth', () {
    test('login berhasil mengembalikan profil dan gudang', () async {
      final op = await repo.auth.login(MockNik.budi, kMockPassword);
      expect(op.name, 'Budi Santoso');
      expect(op.warehouseCode, 'WH01');
      expect(await repo.auth.restoreSession(), isNotNull);
    });

    test('NIK tidak terdaftar dan sandi salah memberi pesan yang sama',
        () async {
      Future<String> messageOf(String nik, String pw) async {
        try {
          await repo.auth.login(nik, pw);
          fail('seharusnya gagal');
        } on AuthException catch (e) {
          expect(e.failure, AuthFailure.invalidCredentials);
          return e.message;
        }
      }

      expect(await messageOf('999999', kMockPassword),
          await messageOf(MockNik.budi, 'salah'));
    });

    test('akun nonaktif ditolak dengan pesan khusus', () async {
      expect(
        () => repo.auth.login(MockNik.agus, kMockPassword),
        throwsA(isA<AuthException>().having(
            (e) => e.failure, 'failure', AuthFailure.inactiveAccount)),
      );
    });

    test('logout menghapus sesi', () async {
      await loginBudi();
      await repo.auth.logout();
      expect(await repo.auth.restoreSession(), isNull);
      expect(() => repo.documents.getDocuments(DocumentType.receiving),
          throwsA(isA<NotSignedInException>()));
    });
  });

  group('pembatasan gudang', () {
    test('dokumen WH02 tidak terlihat oleh operator WH01', () async {
      await loginBudi();
      final docs = await repo.documents.getDocuments(DocumentType.receiving);
      expect(docs.every((d) => d.warehouseCode == 'WH01'), isTrue);
      expect(docs.map((d) => d.number), isNot(contains(MockDoc.otherWarehouseRcv)));
      expect(() => repo.documents.getDocument(MockDoc.otherWarehouseRcv),
          throwsA(isA<NotFoundException>()));
    });

    test('kartu stok hanya barang gudang sendiri, pencarian tidak peka huruf',
        () async {
      await loginBudi();
      final all = await repo.stockCard.searchItems('');
      expect(all, hasLength(15));
      final found = await repo.stockCard.searchItems('BAUT');
      expect(found.single.itemCode, 'BRG-0002');
      expect(await repo.stockCard.searchItems('rak besi'), isEmpty);
      expect(() => repo.stockCard.getItem('BRG-0101'),
          throwsA(isA<NotFoundException>()));
    });
  });

  group('submit', () {
    Map<String, DraftLine> full(List<(String, int)> qty) => {
          for (final (code, q) in qty)
            code: DraftLine(itemCode: code, quantity: q),
        };

    test('RCV lengkap: stok, mutasi, riwayat, status, dan draf', () async {
      await loginBudi();
      final before = await repo.stockCard.getItem('BRG-0001');
      final doc = await repo.documents.getDocument(MockDoc.rcvNew);
      await repo.drafts.saveDraft(Draft(
        documentNumber: doc.number,
        basedOnVersion: doc.version,
        lines: const {},
        updatedAt: DateTime(2026, 11, 21),
      ));

      final trx = await repo.transactions.submit(SubmitRequest(
        documentNumber: doc.number,
        basedOnVersion: doc.version,
        lines: full([
          for (final i in doc.items) (i.itemCode, i.remainingQuantity),
        ]),
        vendorDeliveryNo: 'SJ/BPS/11/0612',
        mode: SubmitMode.close,
      ));

      final after = await repo.stockCard.getItem('BRG-0001');
      expect(after.balance, before.balance + 60);
      final moves = await repo.stockCard.getMovements('BRG-0001');
      expect(moves.first.transactionNumber, trx.number);
      expect(moves.first.operatorNik, MockNik.budi);
      final history = await repo.transactions.getHistory();
      expect(history.first.number, trx.number);
      expect((await repo.documents.getDocument(doc.number)).isOpen, isFalse);
      expect(await repo.drafts.getDraft(doc.number), isNull);
    });

    test('Simpan sebagai Partial membiarkan dokumen OPEN dengan sisa',
        () async {
      await loginBudi();
      final doc = await repo.documents.getDocument(MockDoc.rcvSmall);
      await repo.transactions.submit(SubmitRequest(
        documentNumber: doc.number,
        basedOnVersion: doc.version,
        lines: {
          'BRG-0004': const DraftLine(itemCode: 'BRG-0004', quantity: 12),
          'BRG-0005': const DraftLine(itemCode: 'BRG-0005', quantity: 5),
          'BRG-0015': const DraftLine(
              itemCode: 'BRG-0015', quantity: 0, markedUnavailable: true),
        },
        vendorDeliveryNo: 'SIS/DO/2611/1001',
        mode: SubmitMode.keepOpen,
      ));
      final reopened = await repo.documents.getDocument(doc.number);
      expect(reopened.isOpen, isTrue);
      expect(reopened.version, doc.version + 1);
      final thinner = reopened.items.firstWhere((i) => i.itemCode == 'BRG-0005');
      expect(thinner.remainingQuantity, 15);
      expect(reopened.items.first.isFulfilled, isTrue);
    });

    test('Tandai Selesai menutup dokumen walaupun ada kekurangan', () async {
      await loginBudi();
      final doc = await repo.documents.getDocument(MockDoc.rcvSmall);
      final trx = await repo.transactions.submit(SubmitRequest(
        documentNumber: doc.number,
        basedOnVersion: doc.version,
        lines: full([('BRG-0004', 12), ('BRG-0005', 5), ('BRG-0015', 80)]),
        vendorDeliveryNo: 'SIS/DO/2611/1002',
        mode: SubmitMode.close,
      ));
      expect(trx.closedDocument, isTrue);
      expect((await repo.documents.getDocument(doc.number)).isOpen, isFalse);
    });

    test('ditolak kalau ada Pending, tanpa mengubah apa pun', () async {
      await loginBudi();
      final doc = await repo.documents.getDocument(MockDoc.rcvSmall);
      await expectLater(
        repo.transactions.submit(SubmitRequest(
          documentNumber: doc.number,
          basedOnVersion: doc.version,
          lines: full([('BRG-0004', 12)]),
          vendorDeliveryNo: 'SJ-1',
          mode: SubmitMode.close,
        )),
        throwsA(isA<SubmitException>()
            .having((e) => e.check?.problem, 'problem',
                SubmitProblem.pendingItems)),
      );
      expect((await repo.documents.getDocument(doc.number)).version,
          doc.version);
    });

    test('INT ditolak kalau melebihi saldo stok', () async {
      await loginBudi();
      final doc = await repo.documents.getDocument(MockDoc.intStockLimit);
      await expectLater(
        repo.transactions.submit(SubmitRequest(
          documentNumber: doc.number,
          basedOnVersion: doc.version,
          lines: full([
            for (final i in doc.items) (i.itemCode, i.remainingQuantity),
          ]),
          vendorDeliveryNo: null,
          mode: SubmitMode.close,
        )),
        throwsA(isA<SubmitException>().having(
            (e) => e.check?.quantityViolation?.problem,
            'problem',
            QuantityProblem.exceedsStock)),
      );
    });

    test('dokumen sudah diselesaikan operator lain: ditolak, draf dibuang',
        () async {
      await loginBudi();
      final doc = await repo.documents.getDocument(MockDoc.rcvContested);
      final lines = full([
        for (final i in doc.items) (i.itemCode, i.remainingQuantity),
      ]);
      await repo.drafts.saveDraft(Draft(
        documentNumber: doc.number,
        basedOnVersion: doc.version,
        lines: lines,
        updatedAt: DateTime(2026, 11, 21),
      ));
      await expectLater(
        repo.transactions.submit(SubmitRequest(
          documentNumber: doc.number,
          basedOnVersion: doc.version,
          lines: lines,
          vendorDeliveryNo: 'SJ-STA-2611-200',
          mode: SubmitMode.close,
        )),
        throwsA(isA<SubmitException>().having((e) => e.failure, 'failure',
            SubmitFailure.documentAlreadySubmitted)),
      );
      expect(await repo.drafts.getDraft(doc.number), isNull);
      final history = await repo.transactions.getHistory();
      expect(history.first.operatorNik, MockNik.rina);
    });

    test('draf lama untuk dokumen yang sudah berubah terdeteksi', () async {
      await loginBudi();
      final draft = await repo.drafts.getDraft(MockDoc.rcvPartial);
      final doc = await repo.documents.getDocument(MockDoc.rcvPartial);
      expect(draft!.basedOnVersion, isNot(doc.version));
      final valid = await repo.drafts.getDraft(MockDoc.intWithDraft);
      final intDoc = await repo.documents.getDocument(MockDoc.intWithDraft);
      expect(valid!.basedOnVersion, intDoc.version);
      expect(await repo.drafts.getDocumentNumbersWithDraft(),
          {MockDoc.rcvPartial, MockDoc.intWithDraft});
    });
  });

  test('area gagal sekali lalu berhasil saat dicoba lagi', () async {
    backend = createSeededBackend(
        latency: Duration.zero, failOnce: {MockArea.documents});
    repo = createMockRepositories(backend);
    await loginBudi();
    await expectLater(repo.documents.getDocuments(DocumentType.intransit),
        throwsA(isA<DataUnavailableException>()));
    expect(await repo.documents.getDocuments(DocumentType.intransit),
        isNotEmpty);
  });
}
