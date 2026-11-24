import 'package:flutter/material.dart';

import 'documents/document_list_screen.dart';
import 'history/history_list_screen.dart';
import 'profile/profile_screen.dart';
import 'stock/stock_card_list_screen.dart';

/// Halaman utama: bottom navigation empat tab. Tab memakai IndexedStack
/// supaya posisi gulir dan isi pencarian tidak hilang saat berpindah tab.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = [
    DocumentListScreen(),
    StockCardListScreen(),
    HistoryListScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // `StackFit.expand` wajib: tab sekarang berupa konten murni tanpa
      // Scaffold sendiri, jadi tiap tab harus diberi tinggi terbatas agar
      // `Expanded` di dalamnya punya ruang.
      body: IndexedStack(
        index: _index,
        sizing: StackFit.expand,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description_rounded),
            label: 'Dokumen',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Kartu Stok',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
