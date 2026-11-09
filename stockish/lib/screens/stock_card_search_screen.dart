import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/user.dart';
import '../viewmodels/stock_card_viewmodel.dart';
import '../widgets/user_info_banner.dart';
import '../widgets/refreshable_list_section.dart';
import 'stock_card_detail_screen.dart';

class StockCardSearchScreen extends StatefulWidget {
  final User user;

  const StockCardSearchScreen({super.key, required this.user});

  @override
  State<StockCardSearchScreen> createState() => _StockCardSearchScreenState();
}

class _StockCardSearchScreenState extends State<StockCardSearchScreen> {
  late final StockCardViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = StockCardViewModel(warehouseCode: widget.user.warehouseCode, token: widget.user.token);
    _viewModel.loadItems();
  }

  // 22 Juli 2026 — dipecah dari ListView.builder tunggal supaya loading/
  // empty state juga scrollable (dibutuhkan RefreshIndicator, konsisten
  // pola _buildLogsList di ProfileScreen/TransactionHistoryScreen).
  Widget _buildItemsList(StockCardViewModel vm) {
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: vm.filteredItems.length,
      itemBuilder: (context, index) {
        final item = vm.filteredItems[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${item.itemCode} • Rak: ${item.rackNumber} • Stok: ${item.currentStock} ${item.unit}',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => StockCardDetailScreen(item: item, token: widget.user.token)),
            ),
          ),
        );
      },
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
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Digital Stock Card', style: TextStyle(color: Colors.white)),
          actions: [
            refreshAppBarAction(_viewModel.refresh),
          ],
        ),
        body: Consumer<StockCardViewModel>(
          builder: (context, vm, _) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      UserInfoBanner(user: widget.user),
                      const SizedBox(height: 8),
                      TextField(
                        onChanged: vm.onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Cari Item Code / Nama Barang',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshableListSection(
                    lastSyncTime: vm.lastRefreshTime,
                    onRefresh: vm.refresh,
                    child: _buildItemsList(vm),
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