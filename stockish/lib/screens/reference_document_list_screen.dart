// screens/reference_document_list_screen.dart (REPLACE FULL — tambah tampilan "Dikunci oleh", 18 Agustus 2026)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_colors.dart';
import '../models/reference_document.dart';
import '../models/user.dart';
import '/services/lock_timer_service.dart';
import '../repositories/reference_document_repository.dart';
import '../viewmodels/reference_document_list_viewmodel.dart';
import '../widgets/user_info_banner.dart';
import '../widgets/refreshable_list_section.dart';
import 'transaction_detail_screen.dart';


class ReferenceDocumentListScreen extends StatefulWidget {
  final User user;
  final TransactionType? initialType;

  const ReferenceDocumentListScreen({super.key, required this.user, this.initialType});

  @override
  State<ReferenceDocumentListScreen> createState() => _ReferenceDocumentListScreenState();
}

class _ReferenceDocumentListScreenState extends State<ReferenceDocumentListScreen> {
  late final ReferenceDocumentListViewModel _viewModel;

  static const _defaultStatus = {
    DocumentStatus.available,
    DocumentStatus.partial,
    DocumentStatus.locked,
  };

  @override
  void initState() {
    super.initState();
    _viewModel = ReferenceDocumentListViewModel(
      token: widget.user.token,
      warehouseName: widget.user.warehouseName,
      contextDefaultType: widget.initialType,
    );
    _viewModel.loadDocuments();
    _viewModel.startPolling(); // 🆕 (7 Agustus 2026) — Targeted Auto-Refresh
  }

  @override
  void dispose() {
    _viewModel.stopPolling(); // 🆕
    _viewModel.dispose();
    super.dispose();
  }

  void _showLockedNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dokumen ini sedang terkunci (Locked), sedang diproses di device lain.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showCompletedNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dokumen ini sudah Selesai (Completed), tidak bisa diproses lagi.'),
        backgroundColor: Colors.grey,
      ),
    );
  }

  void _showConnectionErrorNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⚠️ $message Coba lagi.'),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }

  Future<LockResult> _lockWithRetry(String referenceNumber) async {
    try {
      return await _viewModel.lockDocument(referenceNumber);
    } on DocumentLockException {
      debugPrint('🔍[LOCK] Screen: outcome ambigu, retry sekali... ref=$referenceNumber');
      return await _viewModel.lockDocument(referenceNumber);
    }
  }

  Future<void> _openDocument(ReferenceDocument doc) async {
    LockResult result;
    try {
      result = await _lockWithRetry(doc.referenceNumber);
    } on DocumentLockException catch (e) {
      _showConnectionErrorNotice(e.message);
      return;
    } catch (e) {
      _showConnectionErrorNotice('Terjadi kesalahan tak terduga.');
      return;
    }

    if (!result.locked) {
      if (!mounted) return;
      _showLockedNotice();
      _viewModel.loadDocuments();
      return;
    }

    await _viewModel.loadDocuments();

        LockTimerService().start(
      doc.referenceNumber,
      expiresAt: result.expiresAt,
      token: widget.user.token,
      serverTime: result.serverTime, // 🆕 FIX (clock drift)
    );

    _viewModel.pausePolling(); // 🆕 — List tidak di-dispose saat di-push, hindari poll sia-sia

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionDetailScreen(document: doc, user: widget.user),
      ),
    );

    LockTimerService().cancel();
    _viewModel.resumePolling(); // 🆕

    if (!mounted) return;
    debugPrint('🔍[LOCK] List: balik dari Detail, reload list...');
    await _viewModel.loadDocuments();
    final refreshedStatus = _viewModel.getDocumentStatus(doc.referenceNumber);
    debugPrint('🔍[LOCK] List: status ${doc.referenceNumber} setelah reload = $refreshedStatus');
  }

  Color _statusColor(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.available:
        return Colors.green;
      case DocumentStatus.locked:
        return Colors.orange;
      case DocumentStatus.completed:
        return Colors.grey;
      case DocumentStatus.partial:
        return Colors.blue;
    }
  }

  String _statusLabel(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.available:
        return 'Available';
      case DocumentStatus.locked:
        return 'Locked';
      case DocumentStatus.completed:
        return 'Completed';
      case DocumentStatus.partial:
        return 'Partial';
    }
  }

  // 🆕 (18 Agustus 2026) — label "Nama (NIK)", fallback ke NIK saja kalau
  // lockedByName null (backend gagal resolve, mis. user sudah dihapus).
  String _lockedByLabel(ReferenceDocument doc) {
    final nik = doc.lockedByNik;
    if (nik == null) return '';
    final name = doc.lockedByName;
    return (name != null && name.isNotEmpty) ? '$name ($nik)' : nik;
  }

  String _typeFilterLabel(TransactionType? type) {
    switch (type) {
      case TransactionType.receiving:
        return 'Receiving';
      case TransactionType.intransit:
        return 'Intransit';
      case null:
        return 'Semua';
    }
  }

  String _statusFilterLabel(Set<DocumentStatus> statuses) {
    if (statuses.isEmpty) return 'Semua';
    return statuses.map(_statusLabel).join(', ');
  }

  void _openFilterSheet(ReferenceDocumentListViewModel vm) {
    TransactionType? tempType = vm.typeFilter;
    Set<DocumentStatus> tempStatus = Set.from(vm.statusFilter);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () => setSheetState(() {
                            tempType = vm.contextDefaultType;
                            tempStatus = Set.from(_defaultStatus);
                          }),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Tipe Dokumen', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Semua'),
                          selected: tempType == null,
                          onSelected: (_) => setSheetState(() => tempType = null),
                        ),
                        ChoiceChip(
                          label: const Text('Receiving'),
                          selected: tempType == TransactionType.receiving,
                          onSelected: (_) => setSheetState(() => tempType = TransactionType.receiving),
                        ),
                        ChoiceChip(
                          label: const Text('Intransit'),
                          selected: tempType == TransactionType.intransit,
                          onSelected: (_) => setSheetState(() => tempType = TransactionType.intransit),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      'Bisa pilih lebih dari satu',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Available'),
                          selected: tempStatus.contains(DocumentStatus.available),
                          onSelected: (selected) => setSheetState(() {
                            selected
                                ? tempStatus.add(DocumentStatus.available)
                                : tempStatus.remove(DocumentStatus.available);
                          }),
                        ),
                        FilterChip(
                          label: const Text('Locked'),
                          selected: tempStatus.contains(DocumentStatus.locked),
                          onSelected: (selected) => setSheetState(() {
                            selected
                                ? tempStatus.add(DocumentStatus.locked)
                                : tempStatus.remove(DocumentStatus.locked);
                          }),
                        ),
                        FilterChip(
                          label: const Text('Partial'),
                          selected: tempStatus.contains(DocumentStatus.partial),
                          onSelected: (selected) => setSheetState(() {
                            selected
                                ? tempStatus.add(DocumentStatus.partial)
                                : tempStatus.remove(DocumentStatus.partial);
                          }),
                        ),
                        FilterChip(
                          label: const Text('Completed'),
                          selected: tempStatus.contains(DocumentStatus.completed),
                          onSelected: (selected) => setSheetState(() {
                            selected
                                ? tempStatus.add(DocumentStatus.completed)
                                : tempStatus.remove(DocumentStatus.completed);
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          vm.onTypeFilterChanged(tempType);
                          vm.onStatusFilterChanged(tempStatus);
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('Terapkan Filter', style: TextStyle(color: Colors.white)),
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

  Widget _filterButton(ReferenceDocumentListViewModel vm) {
    final statusIsCustom = !setEquals(vm.statusFilter, _defaultStatus);
    final typeIsCustom = vm.typeFilter != vm.contextDefaultType;
    final activeCount = (typeIsCustom ? 1 : 0) + (statusIsCustom ? 1 : 0);

    return OutlinedButton.icon(
      onPressed: () => _openFilterSheet(vm),
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimaryColor,
        side: BorderSide(color: Colors.grey.shade300),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.filter_list, size: 20),
          if (activeCount > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  '$activeCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      label: const Text('Filter'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: kPrimaryColor,
          title: const Text('Reference Document', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            refreshAppBarAction(_viewModel.refreshWithSync),
          ],
        ),
        body: Consumer<ReferenceDocumentListViewModel>(
          builder: (context, vm, _) {
            final statusIsCustom = !setEquals(vm.statusFilter, _defaultStatus);
            final typeIsCustom = vm.typeFilter != vm.contextDefaultType;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      UserInfoBanner(user: widget.user),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: vm.onSearchChanged,
                              decoration: InputDecoration(
                                hintText: 'Cari No. PO / No. BON',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _filterButton(vm),
                        ],
                      ),
                      if (typeIsCustom || statusIsCustom) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (typeIsCustom)
                                Chip(
                                  label: Text(_typeFilterLabel(vm.typeFilter), style: const TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: kPrimaryColor.withOpacity(0.1),
                                  onDeleted: () => vm.onTypeFilterChanged(vm.contextDefaultType),
                                ),
                              if (statusIsCustom)
                                Chip(
                                  label: Text(_statusFilterLabel(vm.statusFilter), style: const TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: kPrimaryColor.withOpacity(0.1),
                                  onDeleted: () => vm.onStatusFilterChanged(_defaultStatus),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshableListSection(
                    lastSyncTime: vm.lastSyncTime,
                    onRefresh: _viewModel.loadDocuments,
                    child: vm.isLoading
                        ? ListView(
                            children: const [
                              SizedBox(height: 120),
                              Center(child: CircularProgressIndicator()),
                            ],
                          )
                        : vm.filteredDocuments.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 80),
                                  Center(
                                    child: vm.hasError
                                        ? Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.wifi_off, size: 40, color: Colors.grey.shade400),
                                              const SizedBox(height: 12),
                                              const Text(
                                                'Jaringan terganggu, silakan coba lagi.',
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 12),
                                              OutlinedButton(
                                                onPressed: _viewModel.loadDocuments,
                                                child: const Text('Coba Lagi'),
                                              ),
                                            ],
                                          )
                                        : const Text('Dokumen tidak ditemukan.'),
                                  ),
                                ],
                              )
                            : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: vm.filteredDocuments.length,
                              itemBuilder: (context, index) {
                                final doc = vm.filteredDocuments[index];
                                final isLocked = doc.status == DocumentStatus.locked;
                                final isCompleted = doc.status == DocumentStatus.completed;

                                final showVendorName = doc.type == TransactionType.receiving &&
                                    doc.vendorName != null &&
                                    doc.vendorName!.isNotEmpty;

                                return Opacity(
                                  opacity: (isLocked || isCompleted) ? 0.6 : 1,
                                  child: Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(14),
                                      title: Text(doc.referenceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (showVendorName) ...[
                                              Text(
                                                doc.vendorName!,
                                                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                                              ),
                                              const SizedBox(height: 4),
                                            ],
                                            if (doc.type == TransactionType.intransit) ...[
                                              Text(
                                                'Diminta oleh: ${doc.orderBy ?? '-'}',
                                                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                                              ),
                                              if (doc.priorityNote != null && doc.priorityNote!.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Chip(
                                                  label: Text(
                                                    doc.priorityNote!,
                                                    style: const TextStyle(fontSize: 11, color: Colors.white),
                                                  ),
                                                  backgroundColor: Colors.deepOrange,
                                                  padding: EdgeInsets.zero,
                                                  visualDensity: VisualDensity.compact,
                                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                              ],
                                              const SizedBox(height: 4),
                                            ],
                                            Row(
                                              children: [
                                                Chip(
                                                  label: Text(
                                                    doc.type == TransactionType.receiving ? 'Receiving' : 'Intransit',
                                                    style: const TextStyle(fontSize: 11, color: Colors.white),
                                                  ),
                                                  backgroundColor: kPrimaryColor,
                                                  padding: EdgeInsets.zero,
                                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _statusLabel(doc.status),
                                                  style: TextStyle(
                                                    color: _statusColor(doc.status),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            // 🆕 (18 Agustus 2026) — tampilkan siapa yang lock,
                                            // cuma muncul kalau status Locked & ada lockedByNik
                                            // (data null untuk dokumen lain / non-locked).
                                            if (isLocked && doc.lockedByNik != null) ...[
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(Icons.person_outline, size: 13, color: Colors.orange.shade700),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      'Dikunci oleh: ${_lockedByLabel(doc)}',
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        color: Colors.orange.shade700,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.pending_actions, size: 13, color: Colors.grey.shade600),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${vm.unfinishedItemCount(doc.referenceNumber)} item belum selesai',
                                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      trailing: isLocked
                                          ? const Icon(Icons.lock, color: Colors.orange)
                                          : isCompleted
                                              ? const Icon(Icons.lock_outline, color: Colors.grey)
                                              : const Icon(Icons.chevron_right),
                                      onTap: isCompleted
                                          ? _showCompletedNotice
                                          : () => _openDocument(doc),
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}