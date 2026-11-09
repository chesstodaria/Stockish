// screens/dashboard_screen.dart (REPLACE FULL — badge Push Monitoring refresh tiap balik ke Dashboard, 26 Agustus 2026)
import 'package:flutter/material.dart';
import '/constants/app_colors.dart';
import '/models/user.dart';
import '/models/reference_document.dart';
import '/widgets/user_info_banner.dart';
import '/widgets/refreshable_list_section.dart';
import '/services/session/session_service.dart';
import '/screens/reference_document_list_screen.dart';
import '/screens/stock_card_search_screen.dart';
import '/screens/profile_screen.dart';
import '/screens/transaction_history_screen.dart';
import '/screens/print_qr_screen.dart';
import '/screens/performa_screen.dart';
import '/screens/push_monitoring_screen.dart';
import '/viewmodels/push_monitoring_viewmodel.dart';
import '/utils/route_observer.dart'; // 🆕 (26 Agustus 2026)

class DashboardScreen extends StatelessWidget {
  final User user;

  const DashboardScreen({super.key, required this.user});

  void _navigateToReferenceDocument(BuildContext context, TransactionType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReferenceDocumentListScreen(user: user, initialType: type),
      ),
    );
  }

  void _navigateToStockCard(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StockCardSearchScreen(user: user)),
    );
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfileScreen(user: user)),
    );
  }

  void _navigateToTransactionHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TransactionHistoryScreen(user: user)),
    );
  }

  void _navigateToPrintQR(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PrintQrScreen(user: user)),
    );
  }

  void _navigateToPerforma(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PerformaScreen(user: user)),
    );
  }

  void _navigateToPushMonitoring(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PushMonitoringScreen(user: user)),
    );
  }

  Future<void> _handleManualSessionCheck(BuildContext context) async {
    final status = await SessionService().checkNow();
    if (status == SessionCheckStatus.valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi Anda masih aktif.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      if (user.accessMobileOperator)
        _MenuCard(
          icon: Icons.inbox,
          label: 'Receiving',
          onTap: () => _navigateToReferenceDocument(context, TransactionType.receiving),
        ),
      if (user.accessMobileOperator)
        _MenuCard(
          icon: Icons.outbox,
          label: 'Intransit',
          onTap: () => _navigateToReferenceDocument(context, TransactionType.intransit),
        ),
      _MenuCard(
        icon: Icons.credit_card,
        label: 'Digital Stock Card',
        onTap: () => _navigateToStockCard(context),
      ),
      if (user.accessMobileOperator)
        _MenuCard(
          icon: Icons.qr_code,
          label: 'Print QR',
          onTap: () => _navigateToPrintQR(context),
        ),
      if (user.accessMobileOperator)
        _PushMonitoringTile(
          user: user,
          onTap: () => _navigateToPushMonitoring(context),
        ),
      _MenuCard(
        icon: Icons.history,
        label: 'Transaction History',
        onTap: () => _navigateToTransactionHistory(context),
      ),
      if (user.accessMobileSupervisor)
        _MenuCard(
          icon: Icons.bar_chart,
          label: 'Performa',
          onTap: () => _navigateToPerforma(context),
        ),
      _MenuCard(
        icon: Icons.person,
        label: 'Profile',
        onTap: () => _navigateToProfile(context),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        title: const Text('StockFlow Mobile', style: TextStyle(color: Colors.white)),
        actions: [
          refreshAppBarAction(() => _handleManualSessionCheck(context)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserInfoBanner(user: user),
            const SizedBox(height: 28),
            const Text('Menu Utama', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: tiles,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badgeCount;

  const _MenuCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 36, color: kPrimaryColor),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            if (badgeCount != null && badgeCount! > 0)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 18),
                  child: Text(
                    badgeCount! > 99 ? '99+' : '$badgeCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// StatefulWidget terpisah khusus tile ini, karena butuh fetch `pendingCount`
/// (async) buat badge. `_loadCount()` dibungkus try/catch eksplisit — meski
/// `PushMonitoringViewModel.load()` & `ErpPushRepository.getStatus()` sudah
/// defensif (tidak throw), guard di sini tetap dipasang sebagai lapisan
/// terakhir: badge yang gagal fetch TIDAK BOLEH pernah menjatuhkan tile
/// atau tile lain di GridView yang sama.
///
/// 🔧 (26 Agustus 2026) — tambah `RouteAware`. Sebelumnya badge cuma
/// fetch SEKALI di initState() (saat Dashboard pertama kali dibuka),
/// jadi begitu operator retry/submit dari Screen lain lalu balik ke
/// Dashboard, badge nunjukin angka basi sampai app di-restart total.
/// `didPopNext()` dipanggil Flutter OTOMATIS setiap kali Dashboard
/// kembali jadi route teratas yang terlihat (balik dari Screen manapun
/// yang di-push di atasnya — Push Monitoring, Receiving, dll), BUKAN
/// polling background — event-driven, cuma fetch pas benar-benar
/// perlu (Dashboard kelihatan lagi).
class _PushMonitoringTile extends StatefulWidget {
  final User user;
  final VoidCallback onTap;

  const _PushMonitoringTile({required this.user, required this.onTap});

  @override
  State<_PushMonitoringTile> createState() => _PushMonitoringTileState();
}

class _PushMonitoringTileState extends State<_PushMonitoringTile> with RouteAware {
  int? _pendingCount;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadCount();
  }

  Future<void> _loadCount() async {
    try {
      final vm = PushMonitoringViewModel(user: widget.user);
      await vm.load();
      if (!mounted) return;
      setState(() => _pendingCount = vm.pendingCount);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingCount = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _MenuCard(
      icon: Icons.sync_problem,
      label: 'Push Monitoring',
      onTap: widget.onTap,
      badgeCount: _pendingCount,
    );
  }
}