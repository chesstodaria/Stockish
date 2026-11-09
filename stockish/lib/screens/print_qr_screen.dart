import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

import '../constants/app_colors.dart';
import '../models/user.dart';
import '../models/print_job.dart';
import '../viewmodels/print_qr_viewmodel.dart';
import '../widgets/refreshable_list_section.dart';

/// PrintQrScreen — reprint QR label per item, di-scope per Warehouse.
///
/// 🆕 (11 Agustus 2026) — tombol kedua "Print via Jaringan": opsi TAMBAHAN
/// kirim PDF ke StockFlow Admin (mode Print Listener) lewat backend, di
/// samping dialog print Android biasa yang TETAP ada (tidak digantikan).
/// Berguna terutama buat printer USB-only yang cuma "kelihatan" di PC
/// tertentu — operator nggak perlu app pihak ketiga (PrinterShare) buat itu.
class PrintQrScreen extends StatefulWidget {
  final User user;
  const PrintQrScreen({super.key, required this.user});

  @override
  State<PrintQrScreen> createState() => _PrintQrScreenState();
}

class _PrintQrScreenState extends State<PrintQrScreen> {
  late final PrintQrViewModel _viewModel;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = PrintQrViewModel(user: widget.user)..loadItems();
    _searchController.addListener(() => _viewModel.onSearchChanged(_searchController.text));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _handlePrint() async {
    final pdfBytes = await _viewModel.generatePdfBytes();
    if (pdfBytes == null) return;

    try {
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'QR_Labels_${widget.user.warehouseCode}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat PDF: $e')),
      );
    }
  }

  Future<void> _handleNetworkPrint() async {
    try {
      final success = await _viewModel.submitNetworkPrint();
      if (!mounted || !success) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Print job terkirim. Cek status di bawah, atau tunggu Admin mencetak.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Widget _buildItemsList(PrintQrViewModel vm) {
    if (vm.isLoading) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (vm.filteredItems.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('Item tidak ditemukan.')),
        ],
      );
    }
    return ListView.builder(
      itemCount: vm.filteredItems.length,
      itemBuilder: (context, index) {
        final item = vm.filteredItems[index];
        final selected = vm.selectedItemCodes.contains(item.itemCode);
        return CheckboxListTile(
          value: selected,
          onChanged: (_) => vm.toggleSelection(item.itemCode),
          title: Text(item.itemName),
          subtitle: Text('${item.itemCode} • Rak ${item.rackNumber}'),
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PRINTED':
        return Colors.green;
      case 'FAILED':
        return Colors.red;
      case 'EXPIRED':
        return Colors.grey;
      default: // PENDING
        return Colors.orange;
    }
  }

  Widget _buildJobStatusSection(PrintQrViewModel vm) {
    if (vm.recentJobs.isEmpty && !vm.isLoadingJobs) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Status Print via Jaringan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              vm.isLoadingJobs
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      onPressed: vm.refreshJobStatus,
                      visualDensity: VisualDensity.compact,
                    ),
            ],
          ),
          ...vm.recentJobs.take(5).map((job) => _buildJobRow(job)),
        ],
      ),
    );
  }

  Widget _buildJobRow(PrintJob job) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: _statusColor(job.status), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${job.itemCount} item • ${job.status}'
              '${job.failureReason != null ? ' — ${job.failureReason}' : ''}',
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PrintQrViewModel>.value(
      value: _viewModel,
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Print QR', style: TextStyle(color: Colors.white)),
        actions: [
          refreshAppBarAction(_viewModel.refresh),
          Consumer<PrintQrViewModel>(
            builder: (context, vm, _) {
              if (vm.selectedCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: vm.clearSelection,
                child: const Text('Clear', style: TextStyle(color: Colors.white)),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari Item Code / Nama Barang',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Consumer<PrintQrViewModel>(
                  builder: (context, vm, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${vm.selectedCount} item dipilih'),
                        TextButton(
                          onPressed: vm.filteredItems.isEmpty ? null : vm.selectAllFiltered,
                          child: const Text('Pilih Semua (hasil filter)'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Consumer<PrintQrViewModel>(
            builder: (context, vm, _) => _buildJobStatusSection(vm),
          ),
          Expanded(
            child: Consumer<PrintQrViewModel>(
              builder: (context, vm, _) {
                return RefreshableListSection(
                  lastSyncTime: vm.lastRefreshTime,
                  onRefresh: vm.refresh,
                  child: _buildItemsList(vm),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Consumer<PrintQrViewModel>(
            builder: (context, vm, _) {
              final hasSelection = vm.selectedCount > 0;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: (!hasSelection || vm.isGenerating) ? null : _handlePrint,
                    icon: vm.isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.print),
                    label: Text('Print (${vm.selectedCount} item)'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: (!hasSelection || vm.isSubmittingNetworkPrint) ? null : _handleNetworkPrint,
                    icon: vm.isSubmittingNetworkPrint
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi),
                    label: const Text('Print via Jaringan'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
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