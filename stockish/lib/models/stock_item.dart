// models/stock_item.dart (REPLACE FULL — tambah field hasQrCode, 20 Agustus 2026)
import 'item_extension_field.dart';

class StockItem {
  final String itemCode;
  final String itemName;
  final String unit;
  final int currentStock;
  final String warehouseCode;
  final String rackNumber;
  final List<ItemExtensionField> extensionFields;
  final bool hasQrCode; // 🆕 (20 Agustus 2026) — dipakai filter Print QR (reprint only)

  const StockItem({
    required this.itemCode,
    required this.itemName,
    required this.unit,
    required this.currentStock,
    required this.warehouseCode,
    required this.rackNumber,
    this.extensionFields = const [],
    this.hasQrCode = false, // 🆕
  });

  /// 🔧 (12 Agustus 2026) — warehouseCode SEKARANG dari server (backend
  /// ItemResponse sudah punya kolom ini sejak Item#3/WH ID FK, 10 Agustus
  /// 2026, tinggal di-expose). SEBELUMNYA (24 Juli 2026) disuntik dari
  /// parameter warehouseCode user yang login — itu bikin scoping per
  /// Warehouse Digital Stock Card TIDAK PERNAH benar-benar berfungsi
  /// (semua item otomatis "cocok" apapun warehouse aslinya). Ditemukan
  /// lewat pertanyaan user setelah fitur "Show More" nampilin Extension
  /// Field "Kode Gudang" yang justru jujur soal warehouse asli item.
  /// Filter per-Warehouse yang genuinely jalan sekarang dilakukan di
  /// StockCardRepository.searchItems() (bandingkan field ini dengan
  /// warehouseCode user), bukan lagi di titik parsing ini.
  ///
  /// 🆕 (20 Agustus 2026) — tambah parsing `hasQrCode` (backend
  /// `ItemResponse.hasQrCode` sudah ada sejak fitur Generate QR Code,
  /// 30 Juli 2026 — sebelumnya tidak pernah di-expose ke model Mobile ini,
  /// dipakai `GenerateQrCodeService` StockFlow Admin saja). Ditambahkan
  /// sekarang supaya `PrintQrViewModel` bisa filter item yang benar-benar
  /// sudah pernah di-generate QR-nya (reprint saja, bukan item apa pun).
  factory StockItem.fromJson(Map<String, dynamic> json) {
    return StockItem(
      itemCode: json['itemCode'] as String,
      itemName: json['itemName'] as String,
      unit: json['uom'] as String? ?? '',
      currentStock: (json['stockQuantity'] as num?)?.toInt() ?? 0,
      warehouseCode: json['warehouseCode'] as String? ?? '',
      rackNumber: json['rackNumber'] as String? ?? '-',
      extensionFields: (json['extensionFields'] as List<dynamic>?)
              ?.map((e) => ItemExtensionField.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      hasQrCode: json['hasQrCode'] as bool? ?? false, // 🆕
    );
  }
}