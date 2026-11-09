// lib/models/print_job.dart (baru)
class PrintJob {
  final int id;
  final int itemCount;
  final String status; // PENDING/PRINTED/FAILED/EXPIRED
  final String createdAt;
  final String? failureReason;

  PrintJob({
    required this.id,
    required this.itemCount,
    required this.status,
    required this.createdAt,
    this.failureReason,
  });

  factory PrintJob.fromJson(Map<String, dynamic> json) {
    return PrintJob(
      id: json['id'] as int,
      itemCount: json['itemCount'] as int,
      status: json['status'] as String,
      createdAt: json['createdAt'] as String,
      failureReason: json['failureReason'] as String?,
    );
  }
}