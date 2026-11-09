import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../models/user.dart';
import '../models/reference_document.dart';
import '../viewmodels/transaction_history_viewmodel.dart';
import '../widgets/user_info_banner.dart';
import '../widgets/refreshable_list_section.dart';
import '../widgets/activity_log_detail_dialog.dart';

/// Transaction History — log dokumen yang pernah di-submit, di-scope per
/// Warehouse (bukan per NIK seperti Riwayat Aktivitas di Profile). Default
/// tampilan "Punya Saya", toggle "Semua Operator" untuk investigasi level
/// gudang.
///
/// Sekarang pakai TransactionHistoryViewModel (ChangeNotifier) — sebelumnya
/// sengaja StatefulWidget + FutureBuilder + setState biasa (lihat
/// 02_Feature_TransactionHistory.md untuk alasan penundaan MVVM
/// sebelumnya). Ditambah pull-to-refresh (kapabilitas baru, disepakati
/// user — lihat 05_Decision_Log.md).
///
/// 22 Juli 2026 — tambah tombol refresh AppBar + SyncStatusIndicator
/// (widget shared) — menyamakan dengan Reference Document List, supaya
/// tombol AppBar & pull-to-refresh dua-duanya bisa dipakai, dan indikator
/// "Terakhir sync" konsisten tampil di semua layar (lihat 05_Decision_Log.md).
///
/// Popup filter (_openFilterSheet) TETAP di Screen — state sementara
/// (tempScope/tempType/tempStatus) murni UI transient sebelum di-commit,
/// tidak perlu masuk ViewModel. Baru dikirim ke ViewModel.applyFilter()
/// begitu tombol "Terapkan Filter" ditekan.
class TransactionHistoryScreen extends StatefulWidget {
  final User user;
  // BARU (29 Juli 2026) — opsional, default null (artinya pakai default
  // ViewModel: ScopeFilter.mine). Dikirim PerformaScreen sebagai
  // ScopeFilter.all.
  final ScopeFilter? initialScope;

  const TransactionHistoryScreen({super.key, required this.user, this.initialScope});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  late final TransactionHistoryViewModel _viewModel;

  @override
void initState() {
  super.initState();
  _viewModel = TransactionHistoryViewModel(user: widget.user, initialScope: widget.initialScope)
    ..loadLogs();
}

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) => DateFormat('dd MMM yyyy, HH:mm').format(date);

  /// Popup filter — state sementara (tempScope dkk) diedit bebas di dalam
  /// sheet, baru di-commit ke ViewModel kalau tombol "Terapkan Filter"
  /// ditekan. Batal (swipe-down/tap luar) tidak mengubah apa-apa. Logic
  /// TIDAK berubah dari versi lama, cuma target commit-nya ganti dari
  /// setState() Screen jadi _viewModel.applyFilter().
  void _openFilterSheet() {
    var tempScope = _viewModel.scopeFilter;
    TransactionType? tempType = _viewModel.typeFilter;
    DocumentStatus? tempStatus = _viewModel.statusFilter;

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
                            tempScope = ScopeFilter.mine;
                            tempType = null;
                            tempStatus = null;
                          }),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Kepemilikan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Punya Saya'),
                          selected: tempScope == ScopeFilter.mine,
                          onSelected: (_) => setSheetState(() => tempScope = ScopeFilter.mine),
                          selectedColor: kPrimaryColor,
                          labelStyle: TextStyle(
                            color: tempScope == ScopeFilter.mine ? Colors.white : Colors.black87,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('Semua Operator'),
                          selected: tempScope == ScopeFilter.all,
                          onSelected: (_) => setSheetState(() => tempScope = ScopeFilter.all),
                          selectedColor: kPrimaryColor,
                          labelStyle: TextStyle(
                            color: tempScope == ScopeFilter.all ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Semua'),
                          selected: tempStatus == null,
                          onSelected: (_) => setSheetState(() => tempStatus = null),
                        ),
                        ChoiceChip(
                          label: const Text('Selesai'),
                          selected: tempStatus == DocumentStatus.completed,
                          onSelected: (_) => setSheetState(() => tempStatus = DocumentStatus.completed),
                        ),
                        ChoiceChip(
                          label: const Text('Partial'),
                          selected: tempStatus == DocumentStatus.partial,
                          onSelected: (_) => setSheetState(() => tempStatus = DocumentStatus.partial),
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
                          _viewModel.applyFilter(
                            scope: tempScope,
                            type: tempType,
                            status: tempStatus,
                          );
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

  Widget _filterButton(int activeFilterCount) {
    return OutlinedButton.icon(
      onPressed: _openFilterSheet,
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
          if (activeFilterCount > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  '$activeFilterCount',
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

  Widget _buildLogsList(TransactionHistoryViewModel vm) {
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.hasError) {
      // ListView dibungkus biar RefreshIndicator tetap bisa ditarik walau
      // isi cuma pesan error — sama pola dengan ProfileScreen.
      return ListView(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
          const SizedBox(height: 12),
          const Center(child: Text('Gagal memuat riwayat transaksi.')),
          const SizedBox(height: 8),
          const Center(child: Text('Tarik ke bawah untuk coba lagi.', style: TextStyle(fontSize: 12, color: Colors.grey))),
        ],
      );
    }

    final logs = vm.filteredLogs;
    if (logs.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('Tidak ada riwayat transaksi.')),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final isReceiving = log.type == TransactionType.receiving;
        final isPartial = log.status == DocumentStatus.partial;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () => showActivityLogDetail(context, log),
            leading: Icon(
              isReceiving ? Icons.inbox : Icons.outbox,
              color: isReceiving ? Colors.blue : Colors.deepOrange,
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    log.referenceNumber,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isReceiving ? Colors.blue : Colors.deepOrange).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isReceiving ? 'Receiving' : 'Intransit',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isReceiving ? Colors.blue : Colors.deepOrange,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '${_formatDate(log.date)}'
              '${vm.scopeFilter == ScopeFilter.all ? ' • NIK ${log.submittedByNik}' : ''}',
            ),
            trailing: Chip(
              label: Text(
                isPartial ? 'Partial' : 'Selesai',
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
              backgroundColor: isPartial ? Colors.orange : Colors.green,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TransactionHistoryViewModel>.value(
      value: _viewModel,
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Transaction History', style: TextStyle(color: Colors.white)),
        actions: [
          refreshAppBarAction(_viewModel.refresh),
        ],
      ),
      body: Column(
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
                        onChanged: (value) => _viewModel.onSearchChanged(value),
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
                    Consumer<TransactionHistoryViewModel>(
                      builder: (context, vm, _) => _filterButton(vm.activeFilterCount),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<TransactionHistoryViewModel>(
              builder: (context, vm, _) {
                return RefreshableListSection(
                  lastSyncTime: vm.lastRefreshTime,
                  onRefresh: vm.refresh,
                  child: _buildLogsList(vm),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}