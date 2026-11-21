/// Jenis dokumen dan transaksi. RCV bersumber dari Purchase Order,
/// INT dari BON pengeluaran atau transfer internal.
enum DocumentType {
  receiving('RCV', 'Receiving'),
  intransit('INT', 'Intransit');

  const DocumentType(this.code, this.label);

  /// Kode pendek yang tampil di badge, misalnya `RCV`.
  final String code;

  /// Nama lengkap untuk judul dan teks.
  final String label;
}

/// Status dokumen referensi. Hanya [open] yang bisa diproses.
enum DocumentStatus { open, submitted }
