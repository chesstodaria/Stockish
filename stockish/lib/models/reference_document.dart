enum TransactionType { receiving, intransit }

enum DocumentStatus { available, locked, completed, partial }

class ReferenceDocument {
  final String referenceNumber;
  final TransactionType type;
  final String warehouse;
  final DateTime transactionDate;
  DocumentStatus status;

  final String? receiptNo;
  String? vendorDocNo;
  final String? vendorId;
  final String? vendorName;

  final String? orderBy;
  final String? priorityNote;

  // BARU (29 Juli 2026) — kapan dokumen terakhir difinalisasi
  // (COMPLETED/PARTIAL). Null untuk dokumen yang belum pernah final
  // (Available/Locked) ATAU dokumen lama sebelum kolom ini ada.
  final DateTime? finalizedAt;

  // 🆕 (5 Agustus 2026) — dibutuhkan Splash/Opsi A: dipakai buat cek
  // "dokumen ini masih dikunci atas nama NIK saya sendiri?" saat resume
  // app. Null kalau status bukan LOCKED.
  final String? lockedByNik;

  // 🆕 (18 Agustus 2026) — nama operator yang sedang lock, ditampilkan ke
  // operator LAIN di List Screen (beda tujuan dari lockedByNik di atas,
  // yang dipakai logic reclaim). Null kalau lockedByNik null, ATAU kalau
  // backend tidak berhasil resolve nama (edge case) — UI fallback tampilkan
  // NIK saja kalau ini null tapi lockedByNik ada isinya.
  final String? lockedByName;

  factory ReferenceDocument.fromJson(Map<String, dynamic> json, {String warehouseName = ''}) {
    return ReferenceDocument(
      referenceNumber: json['referenceDocNo'] as String,
      type: (json['type'] as String) == 'RECEIVING'
          ? TransactionType.receiving
          : TransactionType.intransit,
      warehouse: warehouseName,
      transactionDate: DateTime.parse(json['transactionDate'] as String),
      status: _statusFromString(json['status'] as String),
      receiptNo: json['receiptNo'] as String?,
      vendorId: json['vendorId'] as String?,
      vendorName: json['vendorName'] as String?,
      orderBy: json['orderBy'] as String?,
      priorityNote: json['priorityNote'] as String?,
      finalizedAt: json['finalizedAt'] != null
          ? DateTime.parse(json['finalizedAt'] as String)
          : null,
      lockedByNik: json['lockedByNik'] as String?,
      lockedByName: json['lockedByName'] as String?,
    );
  }

  static DocumentStatus _statusFromString(String value) {
    switch (value) {
      case 'LOCKED':
        return DocumentStatus.locked;
      case 'COMPLETED':
        return DocumentStatus.completed;
      case 'PARTIAL':
        return DocumentStatus.partial;
      default:
        return DocumentStatus.available;
    }
  }

  Map<String, int>? receivedQuantitySoFar;

  ReferenceDocument({
    required this.referenceNumber,
    required this.type,
    required this.warehouse,
    required this.transactionDate,
    required this.status,
    this.receiptNo,
    this.vendorDocNo,
    this.vendorId,
    this.vendorName,
    this.orderBy,
    this.priorityNote,
    this.receivedQuantitySoFar,
    this.finalizedAt,
    this.lockedByNik,
    this.lockedByName,
  });
}