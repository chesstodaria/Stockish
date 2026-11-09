// lib/models/transaction_item.dart (REPLACE FULL — tambah availableStock, 18 Agustus 2026)
import 'item_extension_field.dart';

enum ItemStatus { pending, complete, partial }

class TransactionItem {
  final String itemCode;
  final String itemName;
  final int referenceQuantity;
  final String uom;
  final String rackNumber;

  int? actualQuantity;
  bool isProcessed;

  // 23 Juli 2026 — NIK operator yang terakhir Save Item ini. Nullable, lihat
  // 05_Decision_Log.md (23 Juli 2026) & 02_Feature_Transaction.md.
  String? processedByNik;

  // BARU (29 Juli 2026) — pasangan processedByNik, snapshot nama. Ditampilkan
  // di badge UI (bukan processedByNik lagi). SELALU diisi/dikosongi bersamaan
  // dengan processedByNik — lihat transaction_item_repository.dart.
  String? processedByName;

  // BARU (12 Agustus 2026) — Extension Field ("Show More"). Dari server via
  // GET /receiving/detail & /intransit/detail (TransactionItemResponse),
  // bukan hasil merge SQLite (beda dari actualQuantity/isProcessed dkk).
  // Class ItemExtensionField sekarang di file bersama (item_extension_field.dart)
  // — dipakai juga oleh StockItem (Digital Stock Card), sama-sama konsumsi
  // extensionFields dari Item Master.
  final List<ItemExtensionField> extensionFields;

  // 🆕 (18 Agustus 2026) — stock tersedia gudang saat ini, dipakai validasi
  // client-side real-time. Backend CUMA isi ini untuk Intransit (barang
  // keluar) — null untuk Receiving (barang masuk, tidak relevan, lihat
  // TransactionItemResponse.java & 05_Decision_Log.md 18 Agustus 2026).
  // ViewModel cukup cek null untuk tahu apakah validasi ini perlu jalan,
  // tidak perlu tahu tipe dokumen secara eksplisit.
  final int? availableStock;

  TransactionItem({
    required this.itemCode,
    required this.itemName,
    required this.referenceQuantity,
    required this.uom,
    required this.rackNumber,
    this.actualQuantity,
    this.isProcessed = false,
    this.processedByNik,
    this.processedByName,
    this.extensionFields = const [],
    this.availableStock,
  });

  // Parsing dari response server. actualQuantity/isProcessed/processedByNik/
  // processedByName TIDAK diisi di sini (default null/false) — semuanya
  // di-merge dari SQLite lokal di TransactionItemRepository.getItems().
  // Server TIDAK mengirim processedByNik/processedByName sama sekali (lihat
  // TransactionItemResponse.java) — badge Mobile 100% sumbernya SQLite lokal.
  // extensionFields & availableStock BEDA — keduanya genuinely dari server,
  // ikut di-parse di sini.
  //
  // ⚠️ FIX (3 Agustus 2026) — rackNumber SEKARANG null-safe (fallback '-').
  // Root cause: dokumen hasil sync ERP asli (Reference Document mapping,
  // item #2) belum punya data rak sama sekali — backend kirim `null`,
  // sebelumnya kode ini maksa cast `as String` (non-nullable), throw
  // TypeError diam-diam ketangkep di ReferenceDocumentListViewModel yang
  // memanggilnya (lihat fix 3 Agustus 2026 di sana), bikin badge "item
  // belum selesai" salah tampil 0 untuk dokumen ERP baru.
  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      itemCode: json['itemCode'] as String,
      itemName: json['itemName'] as String,
      referenceQuantity: json['referenceQuantity'] as int,
      uom: json['uom'] as String,
      rackNumber: (json['rackNumber'] as String?) ?? '-',
      extensionFields: (json['extensionFields'] as List<dynamic>?)
              ?.map((e) => ItemExtensionField.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      availableStock: json['availableStock'] as int?,
    );
  }

  ItemStatus get status {
    if (!isProcessed) return ItemStatus.pending;
    if (actualQuantity == referenceQuantity) return ItemStatus.complete;
    return ItemStatus.partial;
  }

  int get outstandingQuantity {
    final actual = actualQuantity ?? 0;
    final remaining = referenceQuantity - actual;
    return remaining < 0 ? 0 : remaining;
  }
}