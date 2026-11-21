import 'document_type.dart';

/// Satu baris mutasi di kartu stok. Receiving menambah, Intransit
/// mengurangi.
///
/// Diadaptasi dari `stockish/lib/models/stock_movement.dart`, ditambah
/// NIK operator sesuai laporan 2.2.4.
class StockMovement {
  final DateTime date;
  final DocumentType type;

  /// Selalu positif. Arah ditentukan [type].
  final int quantity;

  final String documentNumber;
  final String transactionNumber;
  final String operatorNik;

  /// Saldo setelah mutasi ini.
  final int balanceAfter;

  const StockMovement({
    required this.date,
    required this.type,
    required this.quantity,
    required this.documentNumber,
    required this.transactionNumber,
    required this.operatorNik,
    required this.balanceAfter,
  });

  /// Perubahan bertanda: positif untuk Receiving, negatif untuk Intransit.
  int get signedQuantity =>
      type == DocumentType.receiving ? quantity : -quantity;
}
