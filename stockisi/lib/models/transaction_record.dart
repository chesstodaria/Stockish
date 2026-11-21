import 'document_type.dart';

/// Satu baris barang di transaksi (tabel `transaction_items`).
class TransactionLine {
  final String itemCode;
  final String itemName;
  final String uom;
  final String rackNumber;
  final int quantity;

  /// Item ditandai "Tidak tersedia" saat submit (kuantitas 0).
  final bool markedUnavailable;

  const TransactionLine({
    required this.itemCode,
    required this.itemName,
    required this.uom,
    required this.rackNumber,
    required this.quantity,
    this.markedUnavailable = false,
  });
}

/// Transaksi yang sudah disubmit (tabel `transactions`). Riwayat hanya
/// berisi transaksi berstatus SUBMITTED, jadi status tidak disimpan di sini.
class TransactionRecord {
  final String number;
  final String documentNumber;
  final DocumentType type;
  final String warehouseCode;
  final DateTime submittedAt;
  final String operatorNik;
  final String operatorName;

  /// Nomor surat jalan vendor. Hanya untuk RCV.
  final String? vendorDeliveryNo;

  /// true kalau submit ini menutup dokumen (Tandai Selesai atau semua
  /// item Complete). false untuk Simpan sebagai Partial.
  final bool closedDocument;

  final List<TransactionLine> lines;

  const TransactionRecord({
    required this.number,
    required this.documentNumber,
    required this.type,
    required this.warehouseCode,
    required this.submittedAt,
    required this.operatorNik,
    required this.operatorName,
    required this.vendorDeliveryNo,
    required this.closedDocument,
    required this.lines,
  });
}
