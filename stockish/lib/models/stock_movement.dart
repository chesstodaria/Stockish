enum StockMovementType { receiving, intransit }

extension StockMovementTypeParsing on StockMovementType {
  static StockMovementType fromServerString(String? value) {
    switch (value) {
      case 'RECEIVING':
        return StockMovementType.receiving;
      case 'INTRANSIT':
        return StockMovementType.intransit;
      default:
        return StockMovementType.receiving; // fallback aman, tidak seharusnya kejadian
    }
  }
}

class StockMovement {
  final DateTime date;
  final StockMovementType type;
  final int quantity;
  final String referenceNumber;
  final int balanceAfter;

  const StockMovement({
    required this.date,
    required this.type,
    required this.quantity,
    required this.referenceNumber,
    required this.balanceAfter,
  });

  /// BARU (24 Juli 2026) — parsing dari GET /stock-card (StockMovementResponse
  /// backend). ⚠️ balanceAfter dari server SAAT INI cuma Item.stockQuantity
  /// (angka statis/seed, SAMA untuk semua baris) — backend belum punya
  /// ledger stok yang hitung saldo berjalan per transaksi. Tanggal/tipe/
  /// quantity tetap akurat dari data submit asli.
  factory StockMovement.fromJson(Map<String, dynamic> json) {
    return StockMovement(
      date: DateTime.parse(json['date'] as String),
      type: StockMovementTypeParsing.fromServerString(json['type'] as String?),
      quantity: (json['quantity'] as num).toInt(),
      referenceNumber: json['referenceNumber'] as String,
      balanceAfter: (json['balanceAfter'] as num).toInt(),
    );
  }
}