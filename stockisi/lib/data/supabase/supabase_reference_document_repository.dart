import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/document_type.dart';
import '../../models/reference_document.dart';
import '../repositories/reference_document_repository.dart';
import '../repository_exceptions.dart';

/// Dokumen referensi plus item-nya. RLS sudah membatasi ke gudang operator,
/// jadi tidak ada filter gudang di sini.
class SupabaseReferenceDocumentRepository
    implements ReferenceDocumentRepository {
  final SupabaseClient _client;

  SupabaseReferenceDocumentRepository(this._client);

  static const _select = 'number, type, warehouse_code, counterparty, '
      'document_date, status, version, '
      'reference_document_items(item_code, ordered_quantity, '
      'processed_quantity, items(name, uom, rack_number))';

  @override
  Future<List<ReferenceDocument>> getDocuments(DocumentType type) async {
    try {
      final rows = await _client
          .from('reference_documents')
          .select(_select)
          .eq('type', _code(type))
          .order('document_date', ascending: false);

      final docs = rows.map((row) => _map((row as Map).cast<String, dynamic>())).toList();
      return await _withStock(docs);
    } on PostgrestException {
      throw const DataUnavailableException();
    } catch (_) {
      throw const DataUnavailableException();
    }
  }

  @override
  Future<ReferenceDocument> getDocument(String number) async {
    try {
      final row = await _client
          .from('reference_documents')
          .select(_select)
          .eq('number', number)
          .maybeSingle();
      if (row == null) throw const NotFoundException();

      final docs = await _withStock([_map((row as Map).cast<String, dynamic>())]);
      return docs.first;
    } on NotFoundException {
      rethrow;
    } on PostgrestException {
      throw const DataUnavailableException();
    } catch (_) {
      throw const DataUnavailableException();
    }
  }

  /// Untuk INT, tiap item perlu saldo stok sebagai batas pengeluaran.
  Future<List<ReferenceDocument>> _withStock(
      List<ReferenceDocument> docs) async {
    final needsStock = docs.any((d) => d.type == DocumentType.intransit);
    if (!needsStock) return docs;

    final codes = <String>{
      for (final doc in docs)
        if (doc.type == DocumentType.intransit)
          for (final item in doc.items) item.itemCode,
    }.toList();
    if (codes.isEmpty) return docs;

    final stockRows = await _client
        .from('stocks')
        .select('item_code, quantity')
        .inFilter('item_code', codes);
    final stock = {
      for (final row in stockRows)
        (row as Map)['item_code'] as String: row['quantity'] as int,
    };

    return docs.map((doc) {
      if (doc.type != DocumentType.intransit) return doc;
      return ReferenceDocument(
        number: doc.number,
        type: doc.type,
        warehouseCode: doc.warehouseCode,
        documentDate: doc.documentDate,
        counterparty: doc.counterparty,
        status: doc.status,
        version: doc.version,
        items: [
          for (final item in doc.items)
            ReferenceDocumentItem(
              itemCode: item.itemCode,
              itemName: item.itemName,
              uom: item.uom,
              rackNumber: item.rackNumber,
              orderedQuantity: item.orderedQuantity,
              processedQuantity: item.processedQuantity,
              availableStock: stock[item.itemCode] ?? 0,
            ),
        ],
      );
    }).toList();
  }

  static String _code(DocumentType type) =>
      type == DocumentType.receiving ? 'RCV' : 'INT';

  static ReferenceDocument _map(Map<String, dynamic> json) {
    final items = ((json['reference_document_items'] as List?) ?? const [])
        .map((row) {
          final map = (row as Map).cast<String, dynamic>();
          final item = (map['items'] as Map?)?.cast<String, dynamic>();
          return ReferenceDocumentItem(
            itemCode: map['item_code'] as String,
            itemName: item?['name'] as String? ?? '',
            uom: item?['uom'] as String? ?? '',
            rackNumber: item?['rack_number'] as String? ?? '',
            orderedQuantity: map['ordered_quantity'] as int,
            processedQuantity: map['processed_quantity'] as int,
          );
        })
        .toList();

    items.sort((a, b) => a.itemCode.compareTo(b.itemCode));

    return ReferenceDocument(
      number: json['number'] as String,
      type: json['type'] == 'RCV' ? DocumentType.receiving : DocumentType.intransit,
      warehouseCode: json['warehouse_code'] as String,
      documentDate: DateTime.parse(json['document_date'] as String),
      counterparty: json['counterparty'] as String,
      status: json['status'] == 'OPEN'
          ? DocumentStatus.open
          : DocumentStatus.submitted,
      version: json['version'] as int,
      items: items,
    );
  }
}
