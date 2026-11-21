import '../../models/stock_item.dart';
import '../../models/stock_movement.dart';

/// Kartu stok barang di gudang operator.
abstract class StockCardRepository {
  /// Barang di gudang operator yang kode atau namanya memuat [query]
  /// (tidak peka huruf besar-kecil), urut kode. Query kosong berarti semua.
  ///
  /// Melempar `DataUnavailableException` kalau gagal memuat.
  Future<List<StockItem>> searchItems(String query);

  /// Satu barang beserta saldo terbaru. Melempar `NotFoundException` kalau
  /// barang tidak ada di gudang operator.
  Future<StockItem> getItem(String itemCode);

  /// Riwayat mutasi satu barang, terbaru dulu. List kosong kalau belum
  /// pernah ada mutasi.
  Future<List<StockMovement>> getMovements(String itemCode);
}
