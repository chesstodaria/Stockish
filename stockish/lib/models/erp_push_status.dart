// lib/models/erp_push_status.dart (REPLACE FULL — parsing lebih defensif, 24 Agustus 2026)

/// Model status push ERP per submit — GET /erp-push/status.
/// Status enum backend: PENDING/RETRYING_TRANSIENT/WAITING_LOGIN/
/// NEEDS_MANUAL_RETRY/NEEDS_ADMIN_FIX/SUCCESS (lihat 02_Feature_PushMonitoring.md).
///
/// 🆕 (24 Agustus 2026) — fromJson() dilonggarkan: field yang mestinya wajib
/// (id/idempotencyKey/dst) dikasih fallback aman kalau backend somehow kirim
/// null/tipe tak terduga, DAKALING lempar exception yang bisa menjatuhkan
/// ErpPushRepository.getStatus() di tengah parsing List (1 baris korup bikin
/// SEMUA baris gagal ditampilkan). Trade-off: baris dengan data aneh tetap
/// muncul (dengan nilai placeholder), bukan bikin seluruh list kosong.
class ErpPushStatus {
  final int id;
  final String idempotencyKey;
  final String referenceDocNo;
  final String status;
  final int attemptCount;
  final String? lastAttemptAt;
  final String createdAt;
  final String? resolvedAt;
  final String? errorMessage;

  ErpPushStatus({
    required this.id,
    required this.idempotencyKey,
    required this.referenceDocNo,
    required this.status,
    required this.attemptCount,
    this.lastAttemptAt,
    required this.createdAt,
    this.resolvedAt,
    this.errorMessage,
  });

  factory ErpPushStatus.fromJson(Map<String, dynamic> json) {
    return ErpPushStatus(
      id: (json['id'] as num?)?.toInt() ?? 0,
      idempotencyKey: json['idempotencyKey'] as String? ?? '-',
      referenceDocNo: json['referenceDocNo'] as String? ?? '-',
      status: json['status'] as String? ?? 'UNKNOWN',
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      lastAttemptAt: json['lastAttemptAt'] as String?,
      createdAt: json['createdAt'] as String? ?? '-',
      resolvedAt: json['resolvedAt'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  bool get isSuccess => status == 'SUCCESS';
  bool get isWaitingLogin => status == 'WAITING_LOGIN';
  bool get isAutoRetrying => status == 'PENDING' || status == 'RETRYING_TRANSIENT' || status == 'WAITING_LOGIN';
  bool get needsManualRetry => status == 'NEEDS_MANUAL_RETRY';
  bool get needsAdminFix => status == 'NEEDS_ADMIN_FIX';

  String get displayLabel {
    switch (status) {
      case 'SUCCESS':
        return 'Berhasil';
      case 'PENDING':
        return 'Menunggu diproses';
      case 'RETRYING_TRANSIENT':
        return 'Mencoba ulang otomatis';
      case 'WAITING_LOGIN':
        return 'Menunggu Anda login ulang';
      case 'NEEDS_MANUAL_RETRY':
        return 'Perlu dikirim ulang';
      case 'NEEDS_ADMIN_FIX':
        return 'Perlu perbaikan Admin';
      default:
        return status;
    }
  }
}