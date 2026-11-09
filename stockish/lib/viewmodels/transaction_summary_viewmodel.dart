// lib/viewmodels/transaction_summary_viewmodel.dart
import 'package:flutter/foundation.dart';
import '../models/transaction_item.dart';
import '../models/reference_document.dart';
import '../models/activity_log.dart';
import '../repositories/reference_document_repository.dart';
import '../repositories/transaction_item_repository.dart';
import '../repositories/activity_log_repository.dart';
import '../repositories/audit_log_repository.dart';
import '../services/lock_timer_service.dart';
import '../services/database/database_service.dart';
import '../utils/device_identifier.dart';

enum SubmitResult { success, failure }

class TransactionSummaryViewModel extends ChangeNotifier {
  final String referenceNumber;
  final TransactionType documentType;
  final String submittedByNik;
  final String submittedByName;
  final String warehouseCode;
  final String token;
  final ReferenceDocumentRepository _repository = ReferenceDocumentRepository();
  final TransactionItemRepository _itemRepository = TransactionItemRepository();
  final ActivityLogRepository _activityLogRepository = ActivityLogRepository();
  final AuditLogRepository _auditLogRepository = AuditLogRepository();

  // BARU (4 Agustus 2026) — Idempotency Key, dibuat SEKALI saat ViewModel
  // dibuat (1 instance per sesi Summary, konsisten arsitektur ViewModel
  // per-Screen yang sudah ada). Tetap sama nilainya di setiap retry manual
  // dalam retry-window — itulah yang bikin backend bisa kenali "ini request
  // yang sama, bukan submit baru" kalau network putus di tengah proses.
  late final String _idempotencyKey;

  TransactionSummaryViewModel({
    required this.referenceNumber,
    required this.documentType,
    required this.submittedByNik,
    required this.submittedByName,
    required this.warehouseCode,
    required this.token,
  }) {
    _idempotencyKey =
        '$referenceNumber-$submittedByNik-${DateTime.now().microsecondsSinceEpoch}';
  }

  bool _submitSucceeded = false;
  bool get submitSucceeded => _submitSucceeded;

  bool _retryWindowActive = false;
  bool get retryWindowActive => _retryWindowActive;

  String? _lastErrorMessage;
  String? get lastErrorMessage => _lastErrorMessage;

  String? _lastErrorCode; // BARU (4 Agustus 2026) — dipakai Task #2
  String? get lastErrorCode => _lastErrorCode;

  void beginRetryWindow() {
    debugPrint('🔍[LOCK] SummaryVM.beginRetryWindow() ref=$referenceNumber');
    _retryWindowActive = true;
    LockTimerService().unfreezeWithRetryWindow();
    notifyListeners();
  }

  void cancelRetryWindow() {
    _retryWindowActive = false;
    notifyListeners();
  }

  Future<void> handleRetryWindowExpired() async {
    debugPrint('🔍[LOCK] SummaryVM.handleRetryWindowExpired() MULAI ref=$referenceNumber @ ${DateTime.now()}');
    _retryWindowActive = false;
    await _repository.unlockDocument(referenceNumber, token);
    debugPrint('🔍[LOCK] SummaryVM.handleRetryWindowExpired() unlockDocument selesai');
    notifyListeners();
  }

  Future<SubmitResult> submit({
    required bool asPartial,
    required List<TransactionItem> items,
    String? vendorDocNo,
  }) async {
    final result = documentType == TransactionType.receiving
        ? await _itemRepository.submitReceiving(
            referenceDocNo: referenceNumber,
            vendorDocNo: vendorDocNo ?? '',
            asPartial: asPartial,
            items: items,
            token: token,
            idempotencyKey: _idempotencyKey,
          )
        : await _itemRepository.submitIntransit(
            referenceDocNo: referenceNumber,
            items: items,
            token: token,
            idempotencyKey: _idempotencyKey,
          );

    if (!result.success) {
      _lastErrorMessage = result.errorMessage;
      _lastErrorCode = result.errorCode;
      return SubmitResult.failure;
    }

    _retryWindowActive = false;
    _submitSucceeded = true;

    final finalStatus = asPartial ? DocumentStatus.partial : DocumentStatus.completed;

    await DatabaseService().deleteProgress(referenceNumber);
    LockTimerService().cancel();

    await _activityLogRepository.addLog(
      ActivityLog(
        referenceNumber: referenceNumber,
        type: documentType,
        date: DateTime.now(),
        status: finalStatus,
        submittedByNik: submittedByNik,
        submittedByName: submittedByName,
        warehouseCode: warehouseCode,
        processingDurationSeconds: result.processingDurationSeconds,
        items: items
            .map((item) => ActivityLogItem(
                  itemCode: item.itemCode,
                  itemName: item.itemName,
                  quantity: item.actualQuantity ?? 0,
                  uom: item.uom,
                ))
            .toList(),
      ),
      token,
    );

    final statusLabel = asPartial ? 'Partial' : 'Completed';

    // 🆕 (12 Agustus 2026) — DeviceIdentifier.getInfo() (3 komponen:
    // name/ip/id), bukan get() string gabungan lagi.
    await _auditLogRepository.addLog(
      userNik: submittedByNik,
      userName: submittedByName,
      module: 'Transaksi',
      activity:
          'Submit ${documentType == TransactionType.receiving ? 'Receiving' : 'Intransit'} dokumen $referenceNumber ($statusLabel)',
      device: await DeviceIdentifier.getInfo(),
      token: token,
      category: 'ITEM_RELATED',
      relatedItemCodes: items.map((item) => item.itemCode).toList(),
    );

    notifyListeners();
    return SubmitResult.success;
  }
}