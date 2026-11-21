/// Barang beserta saldonya di satu gudang (tabel `items` + `stocks`).
///
/// Diadaptasi dari `stockish/lib/models/stock_item.dart`.
class StockItem {
  final String itemCode;
  final String itemName;
  final String uom;
  final String warehouseCode;
  final String rackNumber;
  final int balance;

  const StockItem({
    required this.itemCode,
    required this.itemName,
    required this.uom,
    required this.warehouseCode,
    required this.rackNumber,
    required this.balance,
  });
}
