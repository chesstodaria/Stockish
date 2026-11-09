// lib/screens/transaction_summary_screen.dart
import '../viewmodels/transaction_summary_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../models/reference_document.dart';
import '../models/transaction_item.dart';
import '../models/user.dart';
import '../services/lock_timer_service.dart';
import 'package:provider/provider.dart';

// BARU (4 Agustus 2026) — kode error dari backend yang berarti "lock memang
// sudah lepas by design" (bukan gagal jaringan/validasi biasa). Retry-window
// tidak relevan untuk kasus ini — retry manual dijamin gagal lagi karena
// dokumen memang sudah tidak dalam status Locked. Lihat _handleSubmitFailure().
const _lockNoLongerHeldErrorCodes = {'DOCUMENT_NOT_LOCKED', 'NOT_LOCK_OWNER'};

class TransactionSummaryScreen extends StatefulWidget {
  final ReferenceDocument document;
  final List<TransactionItem> items;
  final String? vendorDocNo;
  final User user;
  final VoidCallback? onSubmitSuccess;

  const TransactionSummaryScreen({
    super.key,
    required this.document,
    required this.items,
    this.vendorDocNo,
    required this.user,
    this.onSubmitSuccess,
  });

  @override
  State<TransactionSummaryScreen> createState() => _TransactionSummaryScreenState();
}

class _TransactionSummaryScreenState extends State<TransactionSummaryScreen> {
  late final TransactionSummaryViewModel _viewModel;

  bool _isSubmitting = false;

  ReferenceDocument get document => widget.document;
  List<TransactionItem> get items => widget.items;
  String? get vendorDocNo => widget.vendorDocNo;
  User get user => widget.user;

  @override
  void initState() {
    super.initState();
    _viewModel = TransactionSummaryViewModel(
      referenceNumber: document.referenceNumber,
      documentType: document.type,
      submittedByNik: user.nik,
      warehouseCode: user.warehouseCode,
      token: user.token,
      submittedByName: user.userName,
    );
    context.read<LockTimerService>().addListener(_onLockTimerEvent);
  }

  @override
  void dispose() {
    LockTimerService().removeListener(_onLockTimerEvent);
    super.dispose();
  }

  void _onLockTimerEvent() {
    debugPrint('🔍[LOCK] Summary._onLockTimerEvent() dipanggil, mounted=$mounted, retryWindowActive=${_viewModel.retryWindowActive}');
    if (!mounted || !_viewModel.retryWindowActive) return;
    final event = LockTimerService().lastEvent;
    debugPrint('🔍[LOCK] Summary: event=${event?.type}, ref=${event?.referenceNumber}');
    if (event == null || event.type != LockTimerEventType.expired) return;
    debugPrint('🔍[LOCK] Summary: MEMANGGIL _handleRetryWindowExpired');
    _handleRetryWindowExpired(context, event.referenceNumber);
  }

  bool get _isReceiving => document.type == TransactionType.receiving;

  int get _completeCount =>
      items.where((i) => i.status == ItemStatus.complete).length;
  int get _partialCount =>
      items.where((i) => i.status == ItemStatus.partial).length;

  String _formatDate(DateTime date) => DateFormat('dd MMM yyyy').format(date);

  Color _statusColor(ItemStatus status) {
    switch (status) {
      case ItemStatus.pending:
        return Colors.grey;
      case ItemStatus.complete:
        return Colors.green;
      case ItemStatus.partial:
        return Colors.orange;
    }
  }

  String _statusLabel(ItemStatus status) {
    switch (status) {
      case ItemStatus.pending:
        return 'Pending';
      case ItemStatus.complete:
        return 'Complete';
      case ItemStatus.partial:
        return 'Partial';
    }
  }

  Widget _headerRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSubmit(BuildContext context) {
    if (_isSubmitting) return;

    if (_partialCount > 0) {
      if (_isReceiving) {
        _showPartialChoiceDialog(context);
      } else {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Ada Item Partial'),
            content: Text(
              'Terdapat $_partialCount item dengan Quantity kurang dari referensi. Lanjutkan Submit?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _showSuccessAndExit(context, asPartial: false);
                },
                child: const Text(
                  'Lanjutkan',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      }
      return;
    }

    _showSuccessAndExit(context, asPartial: false);
  }

  void _showPartialChoiceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ada Item Partial'),
        content: Text(
          'Terdapat $_partialCount item dengan Quantity kurang dari referensi.\n\n'
          '"Simpan sebagai Partial" — dokumen belum final, No. PO ini bisa dicari & dibuka lagi nanti untuk delivery lanjutan.\n\n'
          '"Tandai Selesai" — dokumen final, PO tidak bisa diproses lagi lewat StockFlow.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _showSuccessAndExit(context, asPartial: true);
            },
            child: const Text('Simpan sebagai Partial'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _showSuccessAndExit(context, asPartial: false);
            },
            child: const Text(
              'Tandai Selesai',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // 4 Agustus 2026 — dipecah 2 jalur:
  // (1) lock memang sudah lepas by design (DOCUMENT_NOT_LOCKED/NOT_LOCK_OWNER)
  //     → retry-window PERCUMA (dijamin gagal lagi), langsung dialog jelas +
  //     keluar ke List, TIDAK memulai retry window sama sekali.
  // (2) kegagalan lain (network/validasi qty/dst.) → perilaku lama tetap:
  //     SnackBar + retry window 5 menit.
  void _handleSubmitFailure(BuildContext context) {
    final errorCode = _viewModel.lastErrorCode;

    if (errorCode != null && _lockNoLongerHeldErrorCodes.contains(errorCode)) {
      _showLockNoLongerHeldDialog(context);
      return;
    }

    _viewModel.beginRetryWindow();

    if (!context.mounted) return;
    final message = _viewModel.lastErrorMessage ?? 'Submit gagal, jaringan terputus. Coba lagi.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showLockNoLongerHeldDialog(BuildContext context) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_open, color: Colors.orange),
            SizedBox(width: 8),
            Text('Dokumen Sudah Tidak Terkunci'),
          ],
        ),
        content: Text(
          _viewModel.lastErrorMessage ??
              'Dokumen ini sudah tidak dalam status Locked lagi (mungkin sudah '
                  'kadaluarsa, dilepas Admin, atau sudah pernah disubmit '
                  'sebelumnya). Progress yang belum tersubmit tidak bisa '
                  'dilanjutkan dari sini.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // Balik ke List — dokumen ini sudah tidak relevan diproses
              // lanjut dari sini, operator perlu buka ulang dari List kalau
              // memang masih AVAILABLE (bukan pop 3x seperti submit sukses,
              // cukup keluar dari Summary+Detail).
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Kembali ke List', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRetryWindowExpired(BuildContext context, String referenceNumber) async {
    await _viewModel.handleRetryWindowExpired();

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_clock, color: Colors.red),
            SizedBox(width: 8),
            Text('Lock Kadaluarsa'),
          ],
        ),
        content: const Text(
          'Window retry Submit (5 menit) habis tanpa aksi. Reference '
          'Document ini otomatis di-unlock dan bisa diambil device lain. '
          'Progress yang belum tersubmit hilang.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showSuccessAndExit(BuildContext context, {required bool asPartial}) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final result = await _viewModel.submit(asPartial: asPartial, items: items, vendorDocNo: vendorDocNo);

    if (result == SubmitResult.failure) {
      if (!context.mounted) return;
      setState(() => _isSubmitting = false);
      _handleSubmitFailure(context);
      return;
    }

    widget.onSubmitSuccess?.call();

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Submit Berhasil'),
          ],
        ),
        content: Text(
          asPartial
              ? 'Transaksi telah berhasil disubmit ke ERP. Dokumen disimpan sebagai Partial — No. PO ini masih bisa dibuka lagi untuk delivery lanjutan.'
              : 'Transaksi telah berhasil disubmit ke ERP. Reference Document ini akan di-unlock.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _progressStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        debugPrint('🔍[LOCK] Summary.onPopInvoked didPop=$didPop, submitSucceeded=${_viewModel.submitSucceeded}, retryWindowActive=${_viewModel.retryWindowActive}');
        if (didPop && !_viewModel.submitSucceeded) {
          _viewModel.cancelRetryWindow();
          LockTimerService().unfreezeToSliding();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: kPrimaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Transaction Summary',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.amber.shade50,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.amber.shade800,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Periksa kembali data sebelum Submit. Data yang sudah disubmit tidak bisa diedit lagi.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: _isReceiving
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _headerRow('Receipt No.', document.receiptNo ?? '-'),
                        _headerRow(
                          'Vendor Doc. No.',
                          vendorDocNo?.isNotEmpty == true ? vendorDocNo! : '-',
                        ),
                        _headerRow('Vendor ID', document.vendorId ?? '-'),
                        _headerRow('Vendor Name', document.vendorName ?? '-'),
                        _headerRow(
                          'Transaction Date',
                          _formatDate(document.transactionDate),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _headerRow('Warehouse', document.warehouse),
                        _headerRow(
                          'Transaction Date',
                          _formatDate(document.transactionDate),
                        ),
                        _headerRow('Order By', document.orderBy ?? '-'),
                      ],
                    ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: kPrimaryColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _progressStat('Total Item', items.length, Colors.white),
                  _progressStat('Complete', _completeCount, Colors.greenAccent),
                  _progressStat('Partial', _partialCount, Colors.orangeAccent),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(
                        item.itemName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${item.itemCode} • Ref: ${item.referenceQuantity} • Actual: ${item.actualQuantity}',
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(item.status).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel(item.status),
                          style: TextStyle(
                            color: _statusColor(item.status),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                  ),
                  onPressed: _isSubmitting ? null : () => _handleSubmit(context),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Submit Transaction',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}