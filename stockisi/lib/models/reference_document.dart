import 'document_type.dart';

/// Satu baris barang di dokumen referensi (tabel `reference_document_items`).
///
/// Diadaptasi dari `stockish/lib/models/transaction_item.dart`. Bedanya,
/// sisa kuantitas dihitung dari [orderedQuantity] dan [processedQuantity],
/// bukan dikirim jadi oleh backend.
class ReferenceDocumentItem {
  final String itemCode;
  final String itemName;
  final String uom;
  final String rackNumber;

  /// Kuantitas yang tertulis di dokumen.
  final int orderedQuantity;

  /// Total yang sudah diterima atau dikeluarkan lewat transaksi sebelumnya
  /// (submit Partial). 0 untuk dokumen yang belum pernah disubmit.
  final int processedQuantity;

  /// Saldo stok barang ini di gudang saat dokumen dimuat. Hanya diisi
  /// untuk INT (batas pengeluaran), null untuk RCV. Pola sama dengan
  /// `availableStock` di kode lama.
  final int? availableStock;

  const ReferenceDocumentItem({
    required this.itemCode,
    required this.itemName,
    required this.uom,
    required this.rackNumber,
    required this.orderedQuantity,
    required this.processedQuantity,
    this.availableStock,
  });

  /// Target untuk transaksi berikutnya.
  int get remainingQuantity {
    final remaining = orderedQuantity - processedQuantity;
    return remaining < 0 ? 0 : remaining;
  }

  /// Sudah terpenuhi di transaksi sebelumnya, tidak perlu diproses lagi.
  bool get isFulfilled => remainingQuantity == 0;
}

/// Dokumen referensi RCV atau INT (tabel `reference_documents`).
class ReferenceDocument {
  final String number;
  final DocumentType type;
  final String warehouseCode;
  final DateTime documentDate;

  /// Vendor untuk RCV, tujuan pengeluaran untuk INT.
  final String counterparty;

  final DocumentStatus status;

  /// Naik setiap kali ada transaksi yang disubmit untuk dokumen ini.
  /// Dipakai untuk mendeteksi dokumen yang berubah sejak draf dibuat
  /// atau sejak dokumen dibuka (diproses operator lain).
  final int version;

  final List<ReferenceDocumentItem> items;

  const ReferenceDocument({
    required this.number,
    required this.type,
    required this.warehouseCode,
    required this.documentDate,
    required this.counterparty,
    required this.status,
    required this.version,
    required this.items,
  });

  bool get isOpen => status == DocumentStatus.open;

  int get itemCount => items.length;

  /// Jumlah item yang sudah terpenuhi, untuk teks progres
  /// "3 dari 5 item terpenuhi".
  int get fulfilledItemCount => items.where((i) => i.isFulfilled).length;

  /// Pernah disubmit sebagai Partial dan masih OPEN.
  bool get hasPartialProgress =>
      isOpen && items.any((i) => i.processedQuantity > 0);
}
