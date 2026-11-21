import '../../models/draft.dart';
import '../../models/transaction_record.dart';

enum SubmitMode {
  /// Simpan sebagai Partial: dokumen tetap OPEN untuk sisanya.
  keepOpen,

  /// Tandai Selesai: dokumen menjadi SUBMITTED walaupun ada kekurangan.
  /// Dipakai juga kalau tidak ada item Partial.
  close,
}

/// Permintaan submit satu dokumen.
class SubmitRequest {
  final String documentNumber;

  /// Versi dokumen saat operator mulai menginput. Kalau versi di server
  /// sudah berbeda, submit ditolak dengan `documentChanged`.
  final int basedOnVersion;

  final Map<String, DraftLine> lines;

  /// Wajib untuk RCV, diabaikan untuk INT.
  final String? vendorDeliveryNo;

  final SubmitMode mode;

  const SubmitRequest({
    required this.documentNumber,
    required this.basedOnVersion,
    required this.lines,
    required this.vendorDeliveryNo,
    required this.mode,
  });
}

/// Transaksi yang sudah disubmit, dan submit itu sendiri.
abstract class TransactionRepository {
  /// Menyimpan transaksi dalam satu langkah utuh: stok bertambah (RCV) atau
  /// berkurang (INT), mutasi tercatat di kartu stok, transaksi masuk
  /// riwayat, status dokumen diperbarui, dan draf dokumen itu dibuang.
  /// Kalau gagal, tidak ada yang berubah.
  ///
  /// Status dokumen setelah submit: SUBMITTED kalau mode `close` atau semua
  /// sisa sudah terpenuhi, selain itu tetap OPEN.
  ///
  /// Melempar `SubmitException`:
  /// - `rulesNotMet` kalau aturan CONTEXT 6 dilanggar (diperiksa ulang di
  ///   sini, tidak percaya pada layar).
  /// - `documentAlreadySubmitted` atau `documentChanged` kalau dokumen
  ///   sudah diproses operator lain. Draf dokumen itu ikut dibuang.
  ///
  /// Melempar `DataUnavailableException` kalau server tidak bisa dihubungi;
  /// dalam kasus ini tidak ada yang berubah dan draf tetap ada.
  Future<TransactionRecord> submit(SubmitRequest request);

  /// Transaksi SUBMITTED di gudang operator, terbaru dulu.
  Future<List<TransactionRecord>> getHistory();

  /// Satu transaksi. Melempar `NotFoundException` kalau bukan milik
  /// gudang operator.
  Future<TransactionRecord> getTransaction(String number);
}
