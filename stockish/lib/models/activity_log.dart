import 'reference_document.dart';

class ActivityLogItem {
  final String itemCode;
  final String itemName;
  final int quantity;
  final String uom;

  ActivityLogItem({
    required this.itemCode,
    required this.itemName,
    required this.quantity,
    required this.uom,
  });

  Map<String, dynamic> toJson() {
    return {
      'itemCode': itemCode,
      'itemName': itemName,
      'quantity': quantity,
      'uom': uom,
    };
  }

  factory ActivityLogItem.fromJson(Map<String, dynamic> json) {
    return ActivityLogItem(
      itemCode: json['itemCode'] as String,
      itemName: json['itemName'] as String,
      quantity: json['quantity'] as int,
      uom: json['uom'] as String,
    );
  }
}

class ActivityLog {
  final String referenceNumber;
  final TransactionType type;
  final DateTime date;
  final DocumentStatus status;
  final String submittedByNik;
  final String submittedByName;
  final String warehouseCode;
  final List<ActivityLogItem> items;
  final int? processingDurationSeconds; // BARU (29 Juli 2026) — fitur Performa

  ActivityLog({
    required this.referenceNumber,
    required this.type,
    required this.date,
    required this.status,
    required this.submittedByNik,
    required this.submittedByName,
    required this.warehouseCode,
    this.items = const [],
    this.processingDurationSeconds,
  });

  // `date` TIDAK dikirim — server generate timestamp sendiri
  // (LocalDateTime.now() di ActivityLogService).
  Map<String, dynamic> toJson() {
    return {
      'referenceNumber': referenceNumber,
      'type': type == TransactionType.receiving ? 'RECEIVING' : 'INTRANSIT',
      'status': status == DocumentStatus.completed ? 'COMPLETED' : 'PARTIAL',
      'submittedByNik': submittedByNik,
      'submittedByName': submittedByName,
      'warehouseCode': warehouseCode,
      'processingDurationSeconds': processingDurationSeconds,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      referenceNumber: json['referenceNumber'] as String,
      type: (json['type'] as String) == 'RECEIVING'
          ? TransactionType.receiving
          : TransactionType.intransit,
      date: DateTime.parse(json['date'] as String),
      status: (json['status'] as String) == 'COMPLETED'
          ? DocumentStatus.completed
          : DocumentStatus.partial,
      submittedByNik: json['submittedByNik'] as String,
      submittedByName: json['submittedByName'] as String? ?? '',
      warehouseCode: json['warehouseCode'] as String,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => ActivityLogItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}