// screens/transaction_detail_screen.dart (REPLACE FULL — saveItem() signature berubah jadi String?, 18 Agustus 2026)
import 'transaction_summary_screen.dart';
import 'qr_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../models/reference_document.dart';
import '../models/transaction_item.dart';
import '../repositories/reference_document_repository.dart';
import '../services/lock_timer_service.dart';
import '../services/lock_validation_service.dart';
import '../viewmodels/transaction_detail_viewmodel.dart';
import '../services/database/database_service.dart';
import '../models/user.dart';
import '../widgets/refreshable_list_section.dart';

class TransactionDetailScreen extends StatefulWidget {
  final ReferenceDocument document;
  final User user;

  const TransactionDetailScreen({super.key, required this.document, required this.user});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final ReferenceDocumentRepository _docRepository = ReferenceDocumentRepository();
  final TextEditingController _vendorDocController = TextEditingController();

  late final TransactionDetailViewModel _viewModel;

  bool _warningDialogOpen = false;
  bool _isSummaryOpen = false;
  bool _lockLostHandled = false;

  bool _submitSucceeded = false;

  bool get _isReceiving => widget.document.type == TransactionType.receiving;

  @override
  void initState() {
    super.initState();

    _viewModel = TransactionDetailViewModel(
      referenceNumber: widget.document.referenceNumber,
      token: widget.user.token,
    );
    _viewModel.loadItems();

    context.read<LockTimerService>().addListener(_onLockTimerEvent);

    context.read<LockValidationService>().addListener(_onLockValidationEvent);
    LockValidationService().start(widget.document.referenceNumber, widget.user.token);
  }

  @override
  void dispose() {
    LockTimerService().removeListener(_onLockTimerEvent);
    LockValidationService().removeListener(_onLockValidationEvent);
    LockValidationService().stop();
    _viewModel.dispose();
    _vendorDocController.dispose();
    super.dispose();
  }

  void _dismissWarningDialogIfOpen() {
    if (_warningDialogOpen && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _warningDialogOpen = false;
    }
  }

  void _onLockTimerEvent() {
    debugPrint('🔍[LOCK] Detail._onLockTimerEvent() dipanggil, mounted=$mounted, _isSummaryOpen=$_isSummaryOpen');
    if (!mounted) return;
    if (_isSummaryOpen) {
      debugPrint('🔍[LOCK] Detail: DIABAIKAN karena _isSummaryOpen=true');
      return;
    }

    final event = LockTimerService().lastEvent;
    if (event == null) return;
    debugPrint('🔍[LOCK] Detail: MEMPROSES event=${event.type} ref=${event.referenceNumber}');

    switch (event.type) {
      case LockTimerEventType.warning:
        _handleLockWarning(event.referenceNumber);
        break;
      case LockTimerEventType.expired:
        _handleLockLost();
        break;
      case LockTimerEventType.reset:
        _dismissWarningDialogIfOpen();
        break;
    }
  }

  void _onLockValidationEvent() {
    if (!mounted) return;
    if (_isSummaryOpen) return;

    final event = LockValidationService().lastEvent;
    if (event == null || event.referenceNumber != widget.document.referenceNumber) return;

    if (event.type == LockValidationEventType.lost) {
      _handleLockLost();
    }
  }

  void _handleLockWarning(String referenceNumber) {
    if (!mounted || _warningDialogOpen) return;
    _warningDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sesi Akan Berakhir'),
        content: Text(
          'Lock dokumen ini akan berakhir dalam '
          '${_formatWarningDuration(LockTimerService.warningBefore)} karena '
          'tidak ada aktivitas. Perpanjang waktu?',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            onPressed: () async {
              Navigator.pop(dialogContext);
              _warningDialogOpen = false;
              await LockTimerService().resetOnActivity();
            },
            child: const Text('Perpanjang Waktu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ).then((_) => _warningDialogOpen = false);
  }

  void _handleLockLost() {
    debugPrint('🔍[LOCK] Detail._handleLockLost() DIPANGGIL @ ${DateTime.now()}');
    if (!mounted || _lockLostHandled) return;
    _lockLostHandled = true;

    final referenceNumber = widget.document.referenceNumber;
    _docRepository.unlockDocument(referenceNumber, widget.user.token);
    LockValidationService().stop();

    final navigator = Navigator.of(context, rootNavigator: true);
    final detailRoute = ModalRoute.of(context);
    if (detailRoute != null) {
      navigator.popUntil((route) => route == detailRoute);
    }
    _warningDialogOpen = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dokumen Tidak Lagi Anda Kuasai'),
        content: const Text(
          'Lock dokumen ini sudah berakhir atau dicabut oleh Admin. '
          'Progress yang belum disubmit tidak bisa dilanjutkan — dokumen '
          'kembali tersedia untuk device lain.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            onPressed: () {
              Navigator.pop(dialogContext);
              navigator.pop();
            },
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleManualLockCheck() async {
    await LockValidationService().checkNow(silent: false);
    if (!mounted) return;

    final event = LockValidationService().lastEvent;
    if (event?.type == LockValidationEventType.stillValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dokumen masih terkunci atas nama Anda.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _formatWarningDuration(Duration d) {
    if (d.inMinutes >= 1) {
      return '${d.inMinutes} menit';
    }
    return '${d.inSeconds} detik';
  }

  Widget? _processedByBadge(String? processedByName) {
    if (processedByName == null) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Text(
        '✓ oleh $processedByName',
        style: TextStyle(
          fontSize: 11,
          color: Colors.blue.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _openItemDialog(TransactionItem item) {
    final quantityController = TextEditingController(
      text: (item.actualQuantity ?? item.referenceQuantity).toString(),
    );

    String? errorText;
    bool isVerified = false;
    bool showExtensionFields = false; // BARU (12 Agustus 2026) — toggle "Show More"

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void showManualInputDialog() {
              final manualCodeController = TextEditingController();
              String? manualError;

              showDialog(
                context: context,
                builder: (dialogContext) {
                  return StatefulBuilder(
                    builder: (dialogContext, setDialogState) {
                      return AlertDialog(
                        title: const Text('Silahkan Input Manual'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Masukkan Item Code untuk: ${item.itemName}',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: manualCodeController,
                              autofocus: true,
                              decoration: InputDecoration(
                                labelText: 'Item Code No.',
                                errorText: manualError,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Kembali'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                            onPressed: () async {
                              final code = manualCodeController.text.trim();

                              if (code.isEmpty) {
                                setDialogState(() => manualError = 'Kode barang wajib diisi.');
                                return;
                              }

                              if (code.toLowerCase() != item.itemCode.toLowerCase()) {
                                setDialogState(() => manualError =
                                    'Kode tidak sesuai dengan item ini (${item.itemCode}).');
                                return;
                              }

                              Navigator.pop(dialogContext);
                              setModalState(() {
                                isVerified = true;
                                errorText = null;
                              });
                              await LockTimerService().resetOnActivity();
                            },
                            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            }

            void showScanFailedDialog() {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('QR Rusak/Tidak Terbaca'),
                  content: const Text('Coba lagi?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Coba lagi'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                      onPressed: () {
                        Navigator.pop(context);
                        showManualInputDialog();
                      },
                      child: const Text('Input Manual', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            }

            Future<void> handleScanTap() async {
              final scannedCode = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (context) => const QRScannerScreen()),
              );

              if (scannedCode == null) return;

              if (scannedCode.toLowerCase() == item.itemCode.toLowerCase()) {
                setModalState(() {
                  isVerified = true;
                  errorText = null;
                });
                await LockTimerService().resetOnActivity();
              } else {
                showScanFailedDialog();
              }
            }

            final processedBadge = _processedByBadge(item.processedByName);

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.itemCode, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.itemName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (processedBadge != null) ...[
                          const SizedBox(width: 8),
                          processedBadge,
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.shelves, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          item.rackNumber,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Expected: ${item.referenceQuantity} ${item.uom}'
                      '${item.isProcessed ? ' • Realized: ${item.actualQuantity} ${item.uom}' : ''}'
                      ' • Outstanding: ${item.outstandingQuantity} ${item.uom}'
                      // 🆕 (18 Agustus 2026) — tampilkan stock tersedia kalau ada
                      // (cuma Intransit — null untuk Receiving, otomatis tidak muncul).
                      '${item.availableStock != null ? ' • Stock Tersedia: ${item.availableStock} ${item.uom}' : ''}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),

                    // BARU (12 Agustus 2026) — "Show More" Extension Field.
                    // Cuma muncul kalau item ini genuinely punya data (list
                    // kosong = section tidak dirender sama sekali).
                    if (item.extensionFields.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => setModalState(() => showExtensionFields = !showExtensionFields),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              showExtensionFields ? 'Sembunyikan Detail' : 'Show More',
                              style: const TextStyle(
                                color: kPrimaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Icon(
                              showExtensionFields ? Icons.expand_less : Icons.expand_more,
                              color: kPrimaryColor,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                      if (showExtensionFields) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: item.extensionFields
                                .map(
                                  (f) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 110,
                                          child: Text(
                                            f.label,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(f.value, style: const TextStyle(fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 16),

                    if (isVerified)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Kode barang terverifikasi',
                                style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    else
                      InkWell(
                        onTap: handleScanTap,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          height: 160,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_scanner, size: 48, color: Colors.grey.shade500),
                              const SizedBox(height: 8),
                              Text('Scan QR', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _isReceiving ? 'Received Quantity' : 'Picked Quantity',
                        suffixText: item.uom,
                        errorText: errorText,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                        onPressed: () async {
                          if (!isVerified) {
                            setModalState(() => errorText =
                                'Verifikasi kode barang (Scan QR / Input Manual) dulu sebelum Save Item.');
                            return;
                          }

                          final inputValue = int.tryParse(quantityController.text);

                          if (inputValue == null) {
                            setModalState(() => errorText = 'Quantity tidak valid.');
                            return;
                          }

                          // 🔧 (18 Agustus 2026) — saveItem() sekarang balikin
                          // String? (pesan error spesifik dari ViewModel),
                          // bukan bool + pesan generik ditebak di sini.
                          // Membedakan "melebihi Ordered/Referensi" vs
                          // "melebihi stock tersedia" (Intransit).
                          final validationError = await _viewModel.saveItem(
                            item,
                            inputValue,
                            widget.user.nik,
                            widget.user.userName,
                          );

                          if (validationError != null) {
                            setModalState(() => errorText = validationError);
                            return;
                          }

                          await LockTimerService().resetOnActivity();

                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Save Item', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 🆕 (7 Agustus 2026) — Item "Not Received" (desain final 6 Agustus 2026).
  /// Reuse `saveItem()` PERSIS SAMA dengan jalur scan/manual — cuma qty
  /// dipaksa 0, gate `isVerified` di-bypass karena method ini tidak pernah
  /// lewat modal (jadi tidak ada gate untuk di-bypass sama sekali).
  /// Status item otomatis kebaca Partial oleh logic existing (qty=0 
  /// Expected>0) — TIDAK ADA logic status baru. `processedByNik`/`Name`
  /// TETAP diisi (ini aksi sadar operator, bukan auto-fill sistem).
  Future<void> _handleNotReceived(TransactionItem item) async {
    await _viewModel.saveItem(item, 0, widget.user.nik, widget.user.userName);

    // Konsisten alur Save Item lain — reset countdown lock, biar operator
    // yang tandai beberapa item "Tidak Diterima" beruntun tidak keburu
    // ke-expire karena dianggap idle.
    await LockTimerService().resetOnActivity();
  }

  Future<void> _handleCancelLock() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Batalkan Proses?'),
        content: const Text(
          'Progress yang belum disubmit akan hilang total dan tidak bisa '
          'dikembalikan. Dokumen ini akan dilepas dan bisa diambil device lain. '
          'Yakin ingin membatalkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final referenceNumber = widget.document.referenceNumber;

    await _docRepository.unlockDocument(referenceNumber, widget.user.token);
    await DatabaseService().deleteProgress(referenceNumber);
    LockTimerService().cancel();
    LockValidationService().stop();

    if (!mounted) return;

    Navigator.pop(context);
  }

  Future<void> _handleReviewAndSubmit() async {
    if (_viewModel.pendingCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak bisa lanjut: masih ada item berstatus Pending.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isReceiving && _vendorDocController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vendor Document No. wajib diisi sebelum lanjut.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    LockTimerService().freeze();
    _isSummaryOpen = true;
    debugPrint('🔍[LOCK] Detail: _isSummaryOpen=true, akan push ke Summary @ ${DateTime.now()}');

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionSummaryScreen(
          document: widget.document,
          items: _viewModel.items,
          vendorDocNo: _isReceiving ? _vendorDocController.text.trim() : null,
          user: widget.user,
          onSubmitSuccess: () => _submitSucceeded = true,
        ),
      ),
    );

    if (mounted) {
      _isSummaryOpen = false;
      debugPrint('🔍[LOCK] Detail: Summary sudah pop, _isSummaryOpen=false lagi @ ${DateTime.now()}');
    }
  }

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

  /// 🆕 (7 Agustus 2026) — diekstrak dari trailing ListTile biar reusable,
  /// dipasang berdampingan dengan tombol shortcut "Not Received".
  Widget _statusChip(ItemStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _statusColor(status).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: _statusColor(status),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _headerRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _progressStat(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  Widget _lockCountdownBadge(BuildContext context) {
    final timerService = context.watch<LockTimerService>();
    if (!timerService.isActive) return const SizedBox.shrink();

    if (timerService.isFrozen) {
      return const Chip(
        avatar: Icon(Icons.pause_circle, size: 18, color: Colors.blueGrey),
        label: Text('Timer freeze'),
      );
    }

    final remaining = timerService.remaining;
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final formatted =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final isWarningZone = remaining <= LockTimerService.warningBefore;

    return Chip(
      avatar: Icon(
        Icons.timer_outlined,
        size: 18,
        color: isWarningZone ? Colors.red : Colors.white,
      ),
      label: Text(formatted),
      backgroundColor: isWarningZone ? Colors.red.shade50 : kPrimaryColor,
      labelStyle: TextStyle(
        color: isWarningZone ? Colors.red : Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;

    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: PopScope(
        canPop: true,
        onPopInvoked: (didPop) {
          debugPrint('🔍[LOCK] Detail.onPopInvoked didPop=$didPop, _submitSucceeded=$_submitSucceeded @ ${DateTime.now()}');
          if (didPop && !_submitSucceeded) {
            _docRepository.unlockDocument(doc.referenceNumber, widget.user.token);
            LockTimerService().cancel();
            LockValidationService().stop();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            backgroundColor: kPrimaryColor,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(doc.referenceNumber, style: const TextStyle(color: Colors.white)),
            actions: [
              refreshAppBarAction(_handleManualLockCheck),
              IconButton(
                icon: const Icon(Icons.cancel_outlined, color: Colors.white),
                tooltip: 'Batalkan Proses',
                onPressed: _handleCancelLock,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(child: _lockCountdownBadge(context)),
              ),
            ],
          ),
          body: Consumer<TransactionDetailViewModel>(
            builder: (context, vm, _) {
              if (vm.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: _isReceiving
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _headerRow('Receipt No.', doc.receiptNo ?? '-'),
                              _headerRow('Vendor ID', doc.vendorId ?? '-'),
                              _headerRow('Vendor Name', doc.vendorName ?? '-'),
                              _headerRow('Transaction Date', _formatDate(doc.transactionDate)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _vendorDocController,
                                decoration: const InputDecoration(
                                  labelText: 'Vendor Doc. No. (No. Surat Jalan)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _headerRow('Warehouse', doc.warehouse),
                              _headerRow('Transaction Date', _formatDate(doc.transactionDate)),
                              _headerRow('Order By', doc.orderBy ?? '-'),
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
                        _progressStat('Pending', vm.pendingCount, Colors.white),
                        _progressStat('Complete', vm.completeCount, Colors.greenAccent),
                        _progressStat('Partial', vm.partialCount, Colors.orangeAccent),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: vm.items.length,
                      itemBuilder: (context, index) {
                        final item = vm.items[index];
                        final processedBadge = _processedByBadge(item.processedByName);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            onTap: () => _openItemDialog(item),
                            title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  '${item.itemCode} • Expected: ${item.referenceQuantity} ${item.uom}'
                                  '${item.isProcessed ? ' • Realized: ${item.actualQuantity} ${item.uom}' : ''}'
                                  ' • Outstanding: ${item.outstandingQuantity} ${item.uom}',
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.shelves, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.rackNumber,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                                if (processedBadge != null) ...[
                                  const SizedBox(height: 4),
                                  processedBadge,
                                ],
                              ],
                            ),
                            trailing: item.status == ItemStatus.pending
                                ? SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.remove_shopping_cart,
                                          color: Colors.red, size: 32),
                                      tooltip: 'Pending — Tap untuk tandai Barang Tidak Diterima',
                                      onPressed: () => _handleNotReceived(item),
                                    ),
                                  )
                                : _statusChip(item.status),
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
                        style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                        onPressed: _handleReviewAndSubmit,
                        child: const Text('Review & Submit', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}