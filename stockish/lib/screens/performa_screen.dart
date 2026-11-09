import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/user.dart';
import '../viewmodels/performa_viewmodel.dart';
import 'transaction_history_screen.dart';
import '../viewmodels/transaction_history_viewmodel.dart'; // untuk ScopeFilter

class PerformaScreen extends StatefulWidget {
  final User user;

  const PerformaScreen({super.key, required this.user});

  @override
  State<PerformaScreen> createState() => _PerformaScreenState();
}

class _PerformaScreenState extends State<PerformaScreen> {
  late final PerformaViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = PerformaViewModel(user: widget.user);
    _viewModel.loadPerformance();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  String _presetLabel(DateRangePreset preset) {
    switch (preset) {
      case DateRangePreset.last7Days:
        return '7 Hari Terakhir';
      case DateRangePreset.last30Days:
        return '30 Hari Terakhir';
      case DateRangePreset.thisMonth:
        return 'Bulan Ini';
    }
  }

  // Format "m" (menit) dan "d" (detik) — keputusan eksplisit user
  // (29 Juli 2026), bukan "m"/"s" ala Inggris.
  String _formatDuration(double? seconds) {
    if (seconds == null) return '-';
    final totalSeconds = seconds.round();
    final minutes = totalSeconds ~/ 60;
    final remainingSeconds = totalSeconds % 60;
    return '${minutes}m ${remainingSeconds}d';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: kPrimaryColor,
          title: const Text('Performa', style: TextStyle(color: Colors.white)),
        ),
        body: Consumer<PerformaViewModel>(
          builder: (context, vm, _) {
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (vm.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    const Text('Gagal memuat data performa.'),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: vm.loadPerformance,
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Preset filter tanggal
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: DateRangePreset.values.map((preset) {
                        final selected = vm.preset == preset;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(_presetLabel(preset)),
                            selected: selected,
                            selectedColor: kPrimaryColor,
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) => vm.changePreset(preset),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Kartu ringkasan
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: 'Transaksi Selesai',
                          value: '${vm.totalCompletedCount}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryCard(
                          label: 'Rata-rata Waktu Transaksi',
                          value: _formatDuration(vm.overallAvgProcessingDurationSeconds),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Text('Per Operator', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 10),

                  if (vm.entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Belum ada transaksi di rentang ini.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  else
                    ...vm.entries.map((entry) {
  final maxCount = vm.entries.isEmpty
      ? 1
      : vm.entries.map((e) => e.completedCount).reduce((a, b) => a > b ? a : b);
  final barFraction = maxCount == 0 ? 0.0 : entry.completedCount / maxCount;

  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: kPrimaryColor.withOpacity(0.15),
            child: Text(
              _initials(entry.name),
              style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${entry.completedCount} transaksi • rata-rata ${_formatDuration(entry.avgProcessingDurationSeconds)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // BARU (29 Juli 2026) — bar proporsional, dibanding completedCount
          // TERTINGGI di antara operator yang tampil (bukan skala absolut) —
          // supaya perbandingan visual tetap jelas kelihatan walau jumlah
          // transaksinya kecil semua atau besar semua.
          Container(
            width: 60,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: barFraction,
              child: Container(
                decoration: BoxDecoration(
                  color: kPrimaryColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => TransactionHistoryScreen(
        user: widget.user,
        initialScope: ScopeFilter.all, // BARU — Supervisor langsung liat semua operator
      ),
    ),
  );
},
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Lihat Detail Lengkap di Transaction History'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}