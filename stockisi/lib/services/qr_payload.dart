/// Isi QR label barang: `kode barang|satuan|kode gudang`
/// (CONTEXT 6), misalnya `BRG-0012|PCS|WH01`. Dipakai Label QR untuk
/// membuat QR dan scanner untuk membacanya.
class QrPayload {
  static const separator = '|';

  final String itemCode;
  final String uom;
  final String warehouseCode;

  const QrPayload({
    required this.itemCode,
    required this.uom,
    required this.warehouseCode,
  });

  String encode() => [itemCode, uom, warehouseCode].join(separator);

  /// Null kalau isi QR tidak sesuai format: harus tepat tiga bagian yang
  /// tidak kosong. Spasi di tepi tiap bagian diabaikan.
  static QrPayload? tryParse(String raw) {
    final parts = raw.trim().split(separator).map((p) => p.trim()).toList();
    if (parts.length != 3 || parts.any((p) => p.isEmpty)) return null;
    return QrPayload(itemCode: parts[0], uom: parts[1], warehouseCode: parts[2]);
  }
}
