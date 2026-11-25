import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/document_type.dart';
import '../../models/stock_item.dart';
import '../../models/stock_movement.dart';
import '../repositories/stock_card_repository.dart';
import '../repository_exceptions.dart';

/// Kartu stok dari `items`, `stocks`, dan `transaction_items`.
///
/// Saldo setelah mutasi tidak disimpan di database; nilainya dihitung mundur
/// dari saldo terkini, supaya angka yang tampil selalu konsisten dengan
/// `stocks.quantity`.
class SupabaseStockCardRepository implements StockCardRepository {
  final SupabaseClient _client;

  SupabaseStockCardRepository(this._client);

  static const _select =
      'code, name, uom, warehouse_code, rack_number, stocks(quantity)';

  @override
  Future<List<StockItem>> searchItems(String query) async {
    try {
      final term = query.trim();
      var request = _client.from('items').select(_select);
      if (term.isNotEmpty) {
        request = request.or('code.ilike.%$term%,name.ilike.%$term%');
      }
      final rows = await request.order('code', ascending: true);
      return rows.map((row) => _mapItem((row as Map).cast<String, dynamic>())).toList();
    } on PostgrestException {
      throw const DataUnavailableException();
    } catch (_) {
      throw const DataUnavailableException();
    }
  }

  @override
  Future<StockItem> getItem(String itemCode) async {
    try {
      final row = await _client
          .from('items')
          .select(_select)
          .eq('code', itemCode)
          .maybeSingle();
      if (row == null) throw const NotFoundException();
      return _mapItem((row as Map).cast<String, dynamic>());
    } on NotFoundException {
      rethrow;
    } on PostgrestException {
      throw const DataUnavailableException();
    } catch (_) {
      throw const DataUnavailableException();
    }
  }

  @override
  Future<List<StockMovement>> getMovements(String itemCode) async {
    try {
      final rows = await _client
          .from('transaction_items')
          .select('item_code, quantity, '
              'transactions!inner(number, type, document_number, submitted_at, '
              'profiles(nik))')
          .eq('item_code', itemCode);

      final parsed = rows.map((row) {
        final map = (row as Map).cast<String, dynamic>();
        final trx = (map['transactions'] as Map).cast<String, dynamic>();
        final profile = (trx['profiles'] as Map?)?.cast<String, dynamic>();
        return (
          at: DateTime.parse(trx['submitted_at'] as String).toLocal(),
          type: trx['type'] == 'RCV'
              ? DocumentType.receiving
              : DocumentType.intransit,
          quantity: map['quantity'] as int,
          documentNumber: trx['document_number'] as String,
          transactionNumber: trx['number'] as String,
          operatorNik: profile?['nik'] as String? ?? '',
        );
      }).where((m) => m.quantity > 0).toList()
        ..sort((a, b) => b.at.compareTo(a.at));

      final item = await getItem(itemCode);

      // Hitung saldo mundur dari saldo terkini.
      var running = item.balance;
      final movements = <StockMovement>[];
      for (final m in parsed) {
        movements.add(StockMovement(
          date: m.at,
          type: m.type,
          quantity: m.quantity,
          documentNumber: m.documentNumber,
          transactionNumber: m.transactionNumber,
          operatorNik: m.operatorNik,
          balanceAfter: running,
        ));
        running -= m.type == DocumentType.receiving ? m.quantity : -m.quantity;
      }
      return movements;
    } on RepositoryException {
      rethrow;
    } on PostgrestException {
      throw const DataUnavailableException();
    } catch (_) {
      throw const DataUnavailableException();
    }
  }

  static StockItem _mapItem(Map<String, dynamic> json) {
    final stocks = (json['stocks'] as List?) ?? const [];
    final quantity = stocks.isEmpty
        ? 0
        : ((stocks.first as Map)['quantity'] as int? ?? 0);
    return StockItem(
      itemCode: json['code'] as String,
      itemName: json['name'] as String,
      uom: json['uom'] as String,
      warehouseCode: json['warehouse_code'] as String,
      rackNumber: json['rack_number'] as String,
      balance: quantity,
    );
  }
}
