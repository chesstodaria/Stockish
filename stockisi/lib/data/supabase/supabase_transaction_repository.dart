import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/document_type.dart';
import '../../models/transaction_record.dart';
import '../repositories/transaction_repository.dart';
import '../repository_exceptions.dart';

/// Submit lewat RPC `submit_transaction` (satu transaksi database), lalu
/// membaca kembali transaksi yang baru dibuat.
///
/// Pesan kesalahan dari RPC memakai kode tetap supaya bisa dipetakan ke
/// pengecualian yang sudah dikenal layar.
class SupabaseTransactionRepository implements TransactionRepository {
  final SupabaseClient _client;

  SupabaseTransactionRepository(this._client);

  static const _select = 'number, document_number, type, warehouse_code, '
      'submitted_at, vendor_delivery_no, closed_document, '
      'transaction_items(item_code, item_name, uom, rack_number, quantity, '
      'marked_unavailable), profiles(name, nik)';

  @override
  Future<TransactionRecord> submit(SubmitRequest request) async {
    try {
      final lines = [
        for (final line in request.lines.values)
          {
            'item_code': line.itemCode,
            'quantity': line.quantity,
            'marked_unavailable': line.markedUnavailable,
          },
      ];

      final result = await _client.rpc('submit_transaction', params: {
        'p_document_number': request.documentNumber,
        'p_based_on_version': request.basedOnVersion,
        'p_lines': lines,
        'p_vendor_delivery_no': request.vendorDeliveryNo,
        'p_mode': request.mode == SubmitMode.close ? 'close' : 'keep_open',
      });

      final number = result is String ? result : result.toString();
      return await getTransaction(number);
    } on PostgrestException catch (e) {
      throw _mapSubmitError(e.message);
    } catch (_) {
      throw const DataUnavailableException();
    }
  }

  @override
  Future<List<TransactionRecord>> getHistory() async {
    try {
      final rows = await _client
          .from('transactions')
          .select(_select)
          .order('submitted_at', ascending: false);
      return rows.map((row) => _map((row as Map).cast<String, dynamic>())).toList();
    } on PostgrestException {
      throw const DataUnavailableException();
    } catch (_) {
      throw const DataUnavailableException();
    }
  }

  @override
  Future<TransactionRecord> getTransaction(String number) async {
    try {
      final row = await _client
          .from('transactions')
          .select(_select)
          .eq('number', number)
          .maybeSingle();
      if (row == null) throw const NotFoundException();
      return _map((row as Map).cast<String, dynamic>());
    } on NotFoundException {
      rethrow;
    } on PostgrestException {
      throw const DataUnavailableException();
    } catch (_) {
      throw const DataUnavailableException();
    }
  }

  static RepositoryException _mapSubmitError(String message) {
    if (message.contains('DOCUMENT_CHANGED')) {
      return const SubmitException(SubmitFailure.documentChanged);
    }
    if (message.contains('ALREADY_SUBMITTED')) {
      return const SubmitException(SubmitFailure.documentAlreadySubmitted);
    }
    if (message.contains('NOT_FOUND')) return const NotFoundException();
    if (message.contains('NOT_SIGNED_IN')) return const NotSignedInException();
    if (message.contains('RULES_NOT_MET')) {
      final text = message.split('RULES_NOT_MET:').last.trim();
      return SubmitException(
        SubmitFailure.rulesNotMet,
        serverMessage: text.isEmpty ? null : text,
      );
    }
    return const DataUnavailableException();
  }

  static TransactionRecord _map(Map<String, dynamic> json) {
    final profile = (json['profiles'] as Map?)?.cast<String, dynamic>();
    final lines = ((json['transaction_items'] as List?) ?? const [])
        .map((row) {
          final map = (row as Map).cast<String, dynamic>();
          return TransactionLine(
            itemCode: map['item_code'] as String,
            itemName: map['item_name'] as String,
            uom: map['uom'] as String,
            rackNumber: map['rack_number'] as String,
            quantity: map['quantity'] as int,
            markedUnavailable: map['marked_unavailable'] as bool? ?? false,
          );
        })
        .toList()
      ..sort((a, b) => a.itemCode.compareTo(b.itemCode));

    return TransactionRecord(
      number: json['number'] as String,
      documentNumber: json['document_number'] as String,
      type: json['type'] == 'RCV'
          ? DocumentType.receiving
          : DocumentType.intransit,
      warehouseCode: json['warehouse_code'] as String,
      submittedAt: DateTime.parse(json['submitted_at'] as String).toLocal(),
      operatorNik: profile?['nik'] as String? ?? '',
      operatorName: profile?['name'] as String? ?? '',
      vendorDeliveryNo: json['vendor_delivery_no'] as String?,
      closedDocument: json['closed_document'] as bool? ?? false,
      lines: lines,
    );
  }
}
