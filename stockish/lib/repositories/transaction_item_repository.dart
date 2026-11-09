// lib/repositories/transaction_item_repository.dart
import 'dart:convert';
import '../models/transaction_item.dart';
import '../models/reference_document.dart';
import '../services/api/api_service.dart';
import '../services/database/database_service.dart';
import 'reference_document_repository.dart';

class TransactionSubmitResult {
  final bool success;
  final String? status;
  final String? errorMessage;
  final String? errorCode; // BARU (4 Agustus 2026) — dipakai Task #2 (pesan error spesifik)
  final int? processingDurationSeconds;
  const TransactionSubmitResult(
    this.success,
    this.status,
    this.errorMessage,
    this.errorCode,
    this.processingDurationSeconds,
  );
}

class TransactionItemRepository {
  final ApiService _apiService = ApiService();
  final ReferenceDocumentRepository _docRepository = ReferenceDocumentRepository();

  Future<List<TransactionItem>> getItems(String referenceNumber, String token) async {
    final doc = await _docRepository.getDocument(referenceNumber);
    final isReceiving = doc?.type != TransactionType.intransit;
    final endpoint = isReceiving ? '/receiving/detail' : '/intransit/detail';

    final response = await _apiService.get('$endpoint?referenceDocNo=$referenceNumber', token: token);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (!(response.statusCode == 200 && decoded['success'] == true)) {
      final message = decoded['message'] as String? ?? 'Gagal mengambil detail item.';
      throw Exception(message);
    }

    final data = decoded['data'] as Map<String, dynamic>;
    final itemsJson = data['items'] as List<dynamic>;
    final serverItems =
        itemsJson.map((e) => TransactionItem.fromJson(e as Map<String, dynamic>)).toList();

    final savedProgress = await DatabaseService().getProgress(referenceNumber);
    final progressByItemCode = {
      for (final row in savedProgress) row['item_code'] as String: row,
    };

    return serverItems.map((item) {
      final saved = progressByItemCode[item.itemCode];
      if (saved != null) {
        return TransactionItem(
          itemCode: item.itemCode,
          itemName: item.itemName,
          referenceQuantity: item.referenceQuantity,
          uom: item.uom,
          rackNumber: item.rackNumber,
          actualQuantity: saved['actual_quantity'] as int,
          isProcessed: (saved['is_processed'] as int) == 1,
          processedByNik: saved['processed_by_nik'] as String?,
          processedByName: saved['processed_by_name'] as String?,
          extensionFields: item.extensionFields,
        );
      }

      final noRemainingWork = item.referenceQuantity <= 0;
      return TransactionItem(
        itemCode: item.itemCode,
        itemName: item.itemName,
        referenceQuantity: item.referenceQuantity,
        uom: item.uom,
        rackNumber: item.rackNumber,
        actualQuantity: noRemainingWork ? 0 : null,
        isProcessed: noRemainingWork,
        processedByNik: null,
        processedByName: null,
        extensionFields: item.extensionFields,
      );
    }).toList();
  }

  Future<TransactionSubmitResult> submitReceiving({
    required String referenceDocNo,
    required String vendorDocNo,
    required bool asPartial,
    required List<TransactionItem> items,
    required String token,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _apiService.post(
        '/receiving/submit',
        {
          'referenceDocNo': referenceDocNo,
          'vendorDocNo': vendorDocNo,
          'asPartial': asPartial,
          'items': items
              .map((i) => {
                    'itemCode': i.itemCode,
                    'actualQuantity': i.actualQuantity ?? 0,
                    'processedByNik': i.processedByNik,
                    'processedByName': i.processedByName,
                  })
              .toList(),
          'idempotencyKey': idempotencyKey,
        },
        token: token,
      );
      return _parseSubmitResponse(response);
    } catch (e) {
      return const TransactionSubmitResult(false, null, 'Gagal terhubung ke server saat submit.', null, null);
    }
  }

  Future<TransactionSubmitResult> submitIntransit({
    required String referenceDocNo,
    required List<TransactionItem> items,
    required String token,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _apiService.post(
        '/intransit/submit',
        {
          'referenceDocNo': referenceDocNo,
          'items': items
              .map((i) => {
                    'itemCode': i.itemCode,
                    'actualQuantity': i.actualQuantity ?? 0,
                    'processedByNik': i.processedByNik,
                    'processedByName': i.processedByName,
                  })
              .toList(),
          'idempotencyKey': idempotencyKey,
        },
        token: token,
      );
      return _parseSubmitResponse(response);
    } catch (e) {
      return const TransactionSubmitResult(false, null, 'Gagal terhubung ke server saat submit.', null, null);
    }
  }

  TransactionSubmitResult _parseSubmitResponse(dynamic response) {
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && decoded['success'] == true) {
      final data = decoded['data'] as Map<String, dynamic>;
      return TransactionSubmitResult(
        true,
        data['status'] as String?,
        null,
        null,
        data['processingDurationSeconds'] as int?,
      );
    }
    final message = decoded['message'] as String? ?? 'Submit gagal.';
    // BARU (4 Agustus 2026) — 'errorCode' sesuai format resmi 10_API_Specification.docx
    // section 10.2 ({success:false, message, errorCode}), dipakai Task #2.
    final errorCode = decoded['errorCode'] as String?;
    return TransactionSubmitResult(false, null, message, errorCode, null);
  }
}