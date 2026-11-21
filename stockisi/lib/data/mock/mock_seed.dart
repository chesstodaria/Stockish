import '../../models/document_type.dart';
import '../../models/draft.dart';
import '../../models/operator_profile.dart';
import '../repositories/transaction_repository.dart';
import 'mock_backend.dart';

/// Kata sandi semua akun dummy.
const String kMockPassword = 'stockisi123';

/// NIK akun dummy, dipakai juga di test.
abstract final class MockNik {
  /// Budi Santoso, WH01, aktif. Akun utama untuk mencoba app.
  static const budi = '210457';

  /// Rina Wulandari, WH01, aktif. "Operator lain" di gudang yang sama.
  static const rina = '210512';

  /// Agus Prasetyo, WH01, nonaktif.
  static const agus = '198803';

  /// Siti Rahmawati, WH02, aktif.
  static const siti = '220118';
}

/// Dokumen yang dipakai untuk mensimulasikan cabang alur tertentu.
abstract final class MockDoc {
  /// RCV OPEN baru.
  static const rcvNew = 'PO-2611-0041';

  /// RCV OPEN dengan progres Partial (3 dari 5 item terpenuhi). Budi punya
  /// draf lama untuk dokumen ini yang dibuat sebelum Rina submit Partial,
  /// jadi melanjutkan draf ini memunculkan "dokumen sudah berubah".
  static const rcvPartial = 'PO-2611-0043';

  /// RCV OPEN yang akan diselesaikan Rina tepat sebelum submit pertama.
  static const rcvContested = 'PO-2611-0046';

  /// RCV OPEN baru, item sedikit.
  static const rcvSmall = 'PO-2611-0048';

  /// INT OPEN dengan progres Partial (2 dari 4 item terpenuhi).
  static const intPartial = 'BON-2611-0012';

  /// INT OPEN baru. Budi punya draf yang masih valid untuk dokumen ini.
  static const intWithDraft = 'BON-2611-0014';

  /// INT OPEN baru. Gas argon diminta 10 TBG padahal saldonya 4 TBG,
  /// untuk menguji batas stok.
  static const intStockLimit = 'BON-2611-0016';

  /// RCV milik WH02, tidak boleh terlihat oleh operator WH01.
  static const otherWarehouseRcv = 'PO-2611-0052';
}

/// Membuat [MockBackend] berisi data dummy gudang manufaktur.
MockBackend createSeededBackend({
  Duration latency = const Duration(milliseconds: 500),
  Set<MockArea> failOnce = const {},
}) {
  const wh01 = 'WH01';
  const wh02 = 'WH02';
  final warehouses = {
    wh01: 'Gudang Bahan Baku Sidoarjo',
    wh02: 'Gudang Barang Jadi Pasuruan',
  };

  MockAccount account(String nik, String name, String wh, bool active) =>
      MockAccount(
        OperatorProfile(
          nik: nik,
          name: name,
          warehouseCode: wh,
          warehouseName: warehouses[wh]!,
          isActive: active,
        ),
        kMockPassword,
      );

  final accounts = {
    MockNik.budi: account(MockNik.budi, 'Budi Santoso', wh01, true),
    MockNik.rina: account(MockNik.rina, 'Rina Wulandari', wh01, true),
    MockNik.agus: account(MockNik.agus, 'Agus Prasetyo', wh01, false),
    MockNik.siti: account(MockNik.siti, 'Siti Rahmawati', wh02, true),
  };

  final itemList = [
    const MockItem('BRG-0001', 'Plat Besi SPCC 1,2 mm 4x8 ft', 'LBR', wh01, 'A-01-01'),
    const MockItem('BRG-0002', 'Baut Hex M10x30 Galvanis', 'PCS', wh01, 'A-02-03'),
    const MockItem('BRG-0003', 'Mur Hex M10 Galvanis', 'PCS', wh01, 'A-02-04'),
    const MockItem('BRG-0004', 'Cat Dasar Epoxy Abu-abu 20 L', 'PAIL', wh01, 'C-01-02'),
    const MockItem('BRG-0005', 'Thinner Epoxy 5 L', 'KLG', wh01, 'C-01-03'),
    const MockItem('BRG-0006', 'Kawat Las ER70S-6 0,8 mm 15 kg', 'ROL', wh01, 'B-03-01'),
    const MockItem('BRG-0007', 'Gas Argon Silinder 6 m³', 'TBG', wh01, 'D-01-01'),
    const MockItem('BRG-0008', 'Kardus Double Wall 60x40x40 cm', 'PCS', wh01, 'E-02-01'),
    const MockItem('BRG-0009', 'Stretch Film 50 cm x 300 m', 'ROL', wh01, 'E-02-03'),
    const MockItem('BRG-0010', 'Pipa Hollow 40x40x2 mm 6 m', 'BTG', wh01, 'A-01-04'),
    const MockItem('BRG-0011', 'Sarung Tangan Katun Bintik', 'PSG', wh01, 'F-01-02'),
    const MockItem('BRG-0012', 'Bearing 6205-2RS', 'PCS', wh01, 'B-01-05'),
    const MockItem('BRG-0013', 'Palet Kayu 120x100 cm', 'PCS', wh01, 'E-01-01'),
    const MockItem('BRG-0014', 'Mata Gerinda Potong 4 inci', 'PCS', wh01, 'B-02-02'),
    const MockItem('BRG-0015', 'Resin Polypropylene Homopolimer 25 kg', 'SAK', wh01, 'C-02-01'),
    const MockItem('BRG-0101', 'Rak Besi Siku 5 Susun', 'UNIT', wh02, 'R-01-01'),
    const MockItem('BRG-0102', 'Kabinet Panel Listrik 40x30 cm', 'UNIT', wh02, 'R-01-02'),
    const MockItem('BRG-0103', 'Kardus Single Wall 40x30x30 cm', 'PCS', wh02, 'R-02-01'),
    const MockItem('BRG-0104', 'Lakban Coklat 2 inci', 'ROL', wh02, 'R-02-02'),
  ];
  final items = {for (final i in itemList) i.code: i};

  MockDocument doc(String number, DocumentType type, String wh,
      DateTime date, String counterparty, Map<String, int> lines) {
    return MockDocument(
      number: number,
      type: type,
      warehouseCode: wh,
      date: date,
      counterparty: counterparty,
      lines: [
        for (final e in lines.entries) MockDocumentLine(e.key, e.value),
      ],
    );
  }

  const rcv = DocumentType.receiving;
  const int_ = DocumentType.intransit;
  const vBaja = 'PT Baja Prima Sentosa';
  const vTeknik = 'CV Sumber Teknik Abadi';
  const vSinar = 'PT Sinar Industri Supply';
  const vMitra = 'PT Mitra Logistik Supply';
  const lini1 = 'Lini Produksi 1 - Fabrikasi Rangka';
  const lini2 = 'Lini Produksi 2 - Pengecatan';

  final docList = [
    // Riwayat WH01 (akan disubmit di bawah).
    doc('PO-2610-0031', rcv, wh01, DateTime(2026, 10, 5), vBaja,
        {'BRG-0001': 120, 'BRG-0010': 80, 'BRG-0006': 30, 'BRG-0007': 12}),
    doc('PO-2610-0034', rcv, wh01, DateTime(2026, 10, 12), vTeknik,
        {'BRG-0002': 2000, 'BRG-0003': 2000, 'BRG-0011': 300, 'BRG-0012': 60}),
    doc('PO-2610-0038', rcv, wh01, DateTime(2026, 10, 19), vSinar, {
      'BRG-0004': 24,
      'BRG-0005': 40,
      'BRG-0008': 500,
      'BRG-0009': 60,
      'BRG-0013': 50,
      'BRG-0015': 200,
    }),
    doc('BON-2610-0019', int_, wh01, DateTime(2026, 10, 27), lini1, {
      'BRG-0001': 40,
      'BRG-0010': 30,
      'BRG-0006': 8,
      'BRG-0002': 600,
      'BRG-0003': 600,
    }),
    doc('BON-2611-0006', int_, wh01, DateTime(2026, 11, 9), lini2,
        {'BRG-0004': 10, 'BRG-0005': 16, 'BRG-0011': 60, 'BRG-0007': 8}),
    doc(MockDoc.rcvPartial, rcv, wh01, DateTime(2026, 11, 16), vMitra, {
      'BRG-0008': 400,
      'BRG-0009': 30,
      'BRG-0013': 40,
      'BRG-0015': 150,
      'BRG-0012': 40,
    }),
    doc(MockDoc.intPartial, int_, wh01, DateTime(2026, 11, 18), lini1,
        {'BRG-0012': 20, 'BRG-0002': 500, 'BRG-0003': 500, 'BRG-0008': 100}),
    // Dokumen OPEN baru WH01.
    doc(MockDoc.rcvNew, rcv, wh01, DateTime(2026, 11, 19), vBaja,
        {'BRG-0001': 60, 'BRG-0010': 40, 'BRG-0014': 100, 'BRG-0006': 20}),
    doc(MockDoc.rcvContested, rcv, wh01, DateTime(2026, 11, 20), vTeknik,
        {'BRG-0002': 1000, 'BRG-0003': 1000, 'BRG-0012': 24}),
    doc(MockDoc.rcvSmall, rcv, wh01, DateTime(2026, 11, 21), vSinar,
        {'BRG-0004': 12, 'BRG-0005': 20, 'BRG-0015': 80}),
    doc(MockDoc.intWithDraft, int_, wh01, DateTime(2026, 11, 20), lini1, {
      'BRG-0001': 20,
      'BRG-0010': 16,
      'BRG-0002': 200,
      'BRG-0003': 200,
      'BRG-0006': 4,
    }),
    doc(MockDoc.intStockLimit, int_, wh01, DateTime(2026, 11, 21), lini2,
        {'BRG-0004': 6, 'BRG-0005': 10, 'BRG-0007': 10, 'BRG-0011': 40}),
    // WH02.
    doc('PO-2611-0049', rcv, wh02, DateTime(2026, 11, 11), 'PT Rakindo Steel', {
      'BRG-0101': 20,
      'BRG-0102': 15,
      'BRG-0103': 1000,
      'BRG-0104': 200,
    }),
    doc('BON-2611-0020', int_, wh02, DateTime(2026, 11, 16),
        'Gudang Distributor Malang', {'BRG-0103': 300, 'BRG-0104': 50}),
    doc(MockDoc.otherWarehouseRcv, rcv, wh02, DateTime(2026, 11, 20),
        'PT Rakindo Steel', {'BRG-0101': 10, 'BRG-0102': 5}),
    doc('BON-2611-0021', int_, wh02, DateTime(2026, 11, 21),
        'Gudang Distributor Malang', {'BRG-0103': 200, 'BRG-0104': 40}),
  ];

  final backend = MockBackend(
    warehouses: warehouses,
    accounts: accounts,
    items: items,
    documents: {for (final d in docList) d.number: d},
    latency: latency,
    failOnce: failOnce,
    contestedDocuments: {MockDoc.rcvContested: MockNik.rina},
  );

  void submit(String nik, String number, DateTime at, Map<String, int> qty,
      {String? deliveryNo,
      SubmitMode mode = SubmitMode.close,
      Set<String> unavailable = const {}}) {
    backend.applySubmit(
      operator: accounts[nik]!.profile,
      request: SubmitRequest(
        documentNumber: number,
        basedOnVersion: backend.documents[number]!.version,
        lines: {
          for (final e in qty.entries)
            e.key: DraftLine(itemCode: e.key, quantity: e.value),
          for (final code in unavailable)
            code: DraftLine(
                itemCode: code, quantity: 0, markedUnavailable: true),
        },
        vendorDeliveryNo: deliveryNo,
        mode: mode,
      ),
      at: at,
    );
  }

  // Riwayat diputar berurutan menurut waktu, lewat aturan submit yang sama
  // dengan app, sehingga saldo, mutasi, dan riwayat pasti konsisten.
  submit(MockNik.budi, 'PO-2610-0031', DateTime(2026, 10, 7, 8, 40),
      {'BRG-0001': 120, 'BRG-0010': 80, 'BRG-0006': 30, 'BRG-0007': 12},
      deliveryNo: 'SJ/BPS/10/0457');
  submit(MockNik.rina, 'PO-2610-0034', DateTime(2026, 10, 14, 10, 15),
      {'BRG-0002': 2000, 'BRG-0003': 2000, 'BRG-0011': 300, 'BRG-0012': 60},
      deliveryNo: 'SJ-STA-2610-118');
  // Tandai Selesai dengan kekurangan: stretch film hanya datang 48 dari 60.
  submit(MockNik.budi, 'PO-2610-0038', DateTime(2026, 10, 21, 13, 5), {
    'BRG-0004': 24,
    'BRG-0005': 40,
    'BRG-0008': 500,
    'BRG-0009': 48,
    'BRG-0013': 50,
    'BRG-0015': 200,
  }, deliveryNo: 'SIS/DO/2610/0912');
  submit(MockNik.rina, 'BON-2610-0019', DateTime(2026, 10, 28, 9, 30), {
    'BRG-0001': 40,
    'BRG-0010': 30,
    'BRG-0006': 8,
    'BRG-0002': 600,
    'BRG-0003': 600,
  });
  submit(MockNik.budi, 'BON-2611-0006', DateTime(2026, 11, 10, 14, 20),
      {'BRG-0004': 10, 'BRG-0005': 16, 'BRG-0011': 60, 'BRG-0007': 8});
  submit(MockNik.siti, 'PO-2611-0049', DateTime(2026, 11, 12, 10, 0), {
    'BRG-0101': 20,
    'BRG-0102': 15,
    'BRG-0103': 1000,
    'BRG-0104': 200,
  }, deliveryNo: 'RKS-SJ-11-0388');
  submit(MockNik.siti, 'BON-2611-0020', DateTime(2026, 11, 17, 11, 25),
      {'BRG-0103': 300, 'BRG-0104': 50});
  // Simpan sebagai Partial: resin kurang, bearing tidak datang.
  submit(MockNik.rina, MockDoc.rcvPartial, DateTime(2026, 11, 18, 9, 10),
      {'BRG-0008': 400, 'BRG-0009': 30, 'BRG-0013': 40, 'BRG-0015': 100},
      unavailable: {'BRG-0012'},
      deliveryNo: 'SJ/MLS/11/2231',
      mode: SubmitMode.keepOpen);
  // Simpan sebagai Partial: bearing dan kardus kurang.
  submit(MockNik.rina, MockDoc.intPartial, DateTime(2026, 11, 19, 15, 45),
      {'BRG-0002': 500, 'BRG-0003': 500, 'BRG-0012': 12, 'BRG-0008': 60},
      mode: SubmitMode.keepOpen);

  // Draf Budi di perangkat.
  backend.draftsOf(MockNik.budi)
    ..[MockDoc.intWithDraft] = Draft(
      documentNumber: MockDoc.intWithDraft,
      basedOnVersion: backend.documents[MockDoc.intWithDraft]!.version,
      lines: const {
        'BRG-0001': DraftLine(itemCode: 'BRG-0001', quantity: 20),
        'BRG-0002': DraftLine(itemCode: 'BRG-0002', quantity: 150),
      },
      updatedAt: DateTime(2026, 11, 21, 7, 55),
    )
    // Dibuat sebelum Rina submit Partial (versi 0), sekarang dokumen versi 1.
    ..[MockDoc.rcvPartial] = Draft(
      documentNumber: MockDoc.rcvPartial,
      basedOnVersion: 0,
      lines: const {
        'BRG-0015': DraftLine(itemCode: 'BRG-0015', quantity: 50),
      },
      updatedAt: DateTime(2026, 11, 17, 16, 30),
    );

  return backend;
}

/// Membaca `--dart-define=STOCKISI_MOCK_FAIL=documents,stockCard` menjadi
/// himpunan area yang gagal sekali.
Set<MockArea> mockFailuresFromEnvironment() {
  const raw = String.fromEnvironment('STOCKISI_MOCK_FAIL');
  if (raw.isEmpty) return {};
  final names = raw.split(',').map((s) => s.trim()).toSet();
  return MockArea.values.where((a) => names.contains(a.name)).toSet();
}
