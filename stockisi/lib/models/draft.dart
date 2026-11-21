/// Input operator untuk satu item dokumen yang belum disubmit.
class DraftLine {
  final String itemCode;

  /// Total kuantitas yang sudah diinput. 0 kalau [markedUnavailable].
  final int quantity;

  /// Ditandai "Tidak tersedia": barang tidak datang (RCV) atau tidak bisa
  /// diambil (INT). Kuantitasnya 0 dan statusnya Partial.
  final bool markedUnavailable;

  const DraftLine({
    required this.itemCode,
    required this.quantity,
    this.markedUnavailable = false,
  });
}

/// Draf transaksi untuk satu dokumen.
///
/// Diadaptasi dari tabel `transaction_progress` di
/// `stockish/lib/services/database/database_service.dart`.
class Draft {
  final String documentNumber;

  /// `ReferenceDocument.version` saat draf disimpan. Kalau dokumen sudah
  /// berubah, draf tidak boleh dilanjutkan.
  final int basedOnVersion;

  /// Kunci: kode barang. Item tanpa baris berarti belum diperiksa (Pending).
  final Map<String, DraftLine> lines;

  final DateTime updatedAt;

  const Draft({
    required this.documentNumber,
    required this.basedOnVersion,
    required this.lines,
    required this.updatedAt,
  });

  bool get isEmpty => lines.isEmpty;
}
