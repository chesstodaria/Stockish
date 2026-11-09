// lib/screens/push_monitoring_screen.dart (baru)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/erp_push_status.dart';
import '../models/user.dart';
import '../viewmodels/push_monitoring_viewmodel.dart';
import '../widgets/refreshable_list_section.dart';

/// PushMonitoringScreen — Lapisan 5, status push transaksi (Receiving &
/// Intransit) ke ERP per operator. Placement hybrid (menu entry kecil +
/// badge merah di Dashboard — lihat PushMonitoringViewModel.pendingCount
/// untuk hitung badge). Notifikasi pasif (bukan auto-redirect).
class PushMonitoringScreen extends StatefulWidget {
  final User user;
  const PushMonitoringScreen({super.key, required this.user});

  @override
  State<PushMonitoringScreen> createState() => _PushMonitoringScreenState();
}

class _PushMonitoringScreenState extends State<PushMonitoringScreen> {
  late final PushMonitoringViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = PushMonitoringViewModel(user: widget.user)..load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _handleRetry(int id) async {
    try {
      await _viewModel.retryItem(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Percobaan kirim ulang diproses.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Color _statusColor(ErpPushStatus item) {
    if (item.isSuccess) return Colors.green;
    if (item.needsAdminFix) return Colors.red;
    if (item.needsManualRetry) return Colors.orange;
    return Colors.blueGrey; // auto-retrying / waiting-login
  }

  Widget _buildCard(ErpPushStatus item) {
    final color = _statusColor(item);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.referenceDocNo,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.displayLabel,
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Percobaan: ${item.attemptCount}'
              '${item.lastAttemptAt != null ? ' • Terakhir: ${item.lastAttemptAt}' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (item.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                item.errorMessage!,
                style: const TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ],
            if (item.needsManualRetry) ...[
              const SizedBox(height: 8),
              Consumer<PushMonitoringViewModel>(
                builder: (context, vm, _) {
                  final retrying = vm.isRetrying(item.id);
                  return SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: retrying ? null : () => _handleRetry(item.id),
                      icon: retrying
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh, size: 18),
                      label: const Text('Kirim Ulang'),
                    ),
                  );
                },
              ),
            ],
            if (item.needsAdminFix) ...[
              const SizedBox(height: 8),
              const Text(
                'Perlu perbaikan data oleh Admin — mengirim ulang dari sini tidak akan membantu.',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildList(PushMonitoringViewModel vm) {
    if (vm.isLoading) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (vm.items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('Belum ada transaksi yang perlu dipantau.')),
        ],
      );
    }
    return ListView.builder(
      itemCount: vm.items.length,
      itemBuilder: (context, index) => _buildCard(vm.items[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PushMonitoringViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: kPrimaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Push Monitoring ERP', style: TextStyle(color: Colors.white)),
          actions: [refreshAppBarAction(_viewModel.refresh)],
        ),
        body: Consumer<PushMonitoringViewModel>(
          builder: (context, vm, _) => RefreshableListSection(
            lastSyncTime: vm.lastRefreshTime,
            onRefresh: vm.refresh,
            child: _buildList(vm),
          ),
        ),
      ),
    );
  }
}