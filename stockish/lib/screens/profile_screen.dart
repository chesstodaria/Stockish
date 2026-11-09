import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/app_colors.dart';
import '../models/user.dart';
import '../models/reference_document.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../widgets/activity_log_detail_dialog.dart';
import '../widgets/sync_status_indicator.dart';
import '../widgets/refreshable_list_section.dart';
import '../screens/login_screen.dart';

/// Profile Screen — MVP: info user read-only, riwayat aktivitas ringkas
/// (transaksi yang pernah di-submit), logout manual, + pull-to-refresh
/// (kapabilitas baru, refactor MVVM).
///
/// Sekarang pakai ProfileViewModel (ChangeNotifier) — sebelumnya sengaja
/// StatefulWidget + FutureBuilder biasa (lihat 02_Feature_Profile.md untuk
/// alasan penundaan MVVM sebelumnya). Ganti Password sengaja masih TIDAK
/// ada di sini — tetap Future Enhancement, bukan bagian refactor ini.
///
/// 22 Juli 2026 — tambah tombol refresh AppBar + SyncStatusIndicator
/// (widget shared) — menyamakan dengan Reference Document List/Transaction
/// History, lihat 05_Decision_Log.md.
///
/// 🆕 11 Agustus 2026 — long-press avatar user membuka "Export Log
/// Diagnostik" (auth_debug_log SQLite → share teks). Sengaja tersembunyi
/// (long-press, bukan tombol biasa) — fitur buat tim IT/investigasi bug,
/// bukan buat operator gudang sehari-hari. Lihat 02_Feature_Authentication.md
/// Known Issues (hipotesis ke-3 "kick sesi misterius").
///
/// 🆕 12 Agustus 2026 — tombol Logout sekarang disable + tampilkan
/// loading indicator selama proses berjalan (guard double-tap, lihat
/// ProfileViewModel.isLoggingOut) — ditemukan saat testing Audit Log
/// Offline Queue, double-tap saat koneksi lambat sempat memicu 2×
/// addLog() terpisah.
class ProfileScreen extends StatefulWidget {
  final User user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ProfileViewModel(user: widget.user)..loadLogs();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) => DateFormat('dd MMM yyyy, HH:mm').format(date);

  /// Dialog konfirmasi wajib sebelum logout — pola sama
  /// _handleCancelLock() di transaction_detail_screen.dart. Service call
  /// (stop polling + clear sesi) sekarang di ViewModel.logout(), Screen
  /// cuma urus dialog + navigasi (butuh BuildContext).
  ///
  /// 🆕 (12 Agustus 2026) — guard di awal: kalau logout() sedang berjalan
  /// (mis. tap kedua nembus sebelum tombol sempat ke-disable di frame
  /// berikutnya), skip buka dialog lagi. Lapis kedua setelah disable
  /// tombol di _buildScaffold() dan guard internal ProfileViewModel.logout().
  Future<void> _handleLogout(BuildContext context) async {
    if (_viewModel.isLoggingOut) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Yakin mau logout dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Ya, Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await _viewModel.logout();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// 🆕 11 Agustus 2026 — dipicu long-press avatar. Dialog konfirmasi
  /// dulu (pola sama _handleLogout) supaya tidak ke-trigger tidak
  /// sengaja, baru ambil isi auth_debug_log & buka share sheet OS
  /// (WA/Email/dst — operator pilih sendiri).
  Future<void> _handleExportDebugLog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Export Log Diagnostik'),
        content: const Text(
          'Bagikan log diagnostik login/sesi dari device ini? '
          'Berguna buat tim IT investigasi masalah sesi/login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Bagikan'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final logText = await _viewModel.exportAuthDebugLog();

    // 🆕 (fix #2) — simpan ke folder EXTERNAL STORAGE app-specific
    // (Android/data/<package>/files/), BUKAN folder temp/cache. Folder
    // ini kelihatan & bisa diambil langsung lewat File Explorer PC pas
    // tablet dicolok USB (MTP) — tidak butuh adb, tidak butuh runtime
    // permission (app-specific external storage sudah diizinkan Android
    // secara default sejak API 19+, tanpa perlu minta izin ke user).
    final extDir = await getExternalStorageDirectory();
    if (extDir == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal akses folder penyimpanan device.')),
      );
      return;
    }

    final fileName =
        'stockflow_auth_log_${DateTime.now().millisecondsSinceEpoch}.txt';
    final file = File('${extDir.path}/$fileName');
    await file.writeAsString(logText);

    if (!context.mounted) return;

    // Dialog konfirmasi + tampilkan path lengkap (biar jelas dicari di
    // File Explorer PC), plus opsi share langsung kalau mau.
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log Tersimpan'),
        content: SelectableText(
          'File tersimpan di:\n\n${file.path}\n\n'
          'Ambil lewat File Explorer PC (colok USB ke tablet, cari folder '
          'Android/data/<nama.package.stockflow>/files/), atau tekan '
          '"Bagikan" untuk kirim langsung sekarang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await SharePlus.instance.share(
                ShareParams(
                  files: [XFile(file.path)],
                  subject: 'StockFlow Auth Debug Log - ${widget.user.nik}',
                ),
              );
            },
            child: const Text('Bagikan'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: kPrimaryColor),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildLogsList(ProfileViewModel vm) {
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.hasError) {
      // ListView dibungkus biar RefreshIndicator tetap bisa ditarik
      // walau isi cuma pesan error (RefreshIndicator butuh child yang
      // scrollable, bukan Center biasa).
      return ListView(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
          const SizedBox(height: 12),
          const Center(child: Text('Gagal memuat riwayat aktivitas.')),
          const SizedBox(height: 8),
          const Center(child: Text('Tarik ke bawah untuk coba lagi.', style: TextStyle(fontSize: 12, color: Colors.grey))),
        ],
      );
    }

    final logs = vm.logs;
    if (logs.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('Belum ada riwayat transaksi.')),
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
            subtitle: Text(_formatDate(log.date)),
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
    final user = widget.user;
    return ChangeNotifierProvider<ProfileViewModel>.value(
      value: _viewModel,
      child: _buildScaffold(user),
    );
  }

  Widget _buildScaffold(User user) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        actions: [
          refreshAppBarAction(_viewModel.refresh),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onLongPress: () => _handleExportDebugLog(context),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: kPrimaryColor.withOpacity(0.1),
                        child: Icon(Icons.person, size: 32, color: kPrimaryColor),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        user.userName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _infoRow(Icons.badge_outlined, 'NIK', user.nik),
                _infoRow(Icons.warehouse_outlined, 'Warehouse', '${user.warehouseName} (${user.warehouseCode})'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Riwayat Aktivitas', style: TextStyle(fontWeight: FontWeight.bold)),
                Consumer<ProfileViewModel>(
                  builder: (context, vm, _) => SyncStatusIndicator(lastSyncTime: vm.lastRefreshTime),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Consumer<ProfileViewModel>(
              builder: (context, vm, _) {
                return RefreshableListSection(
                  lastSyncTime: vm.lastRefreshTime,
                  onRefresh: vm.refresh,
                  showIndicator: false,
                  child: _buildLogsList(vm),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              // 🆕 (12 Agustus 2026) — Consumer biar tombol reaktif ke
              // isLoggingOut tanpa rebuild seluruh Scaffold (pola sama
              // Consumer<ProfileViewModel> lain di file ini).
              child: Consumer<ProfileViewModel>(
                builder: (context, vm, _) {
                  return OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: vm.isLoggingOut ? null : () => _handleLogout(context),
                    icon: vm.isLoggingOut
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                          )
                        : const Icon(Icons.logout),
                    label: Text(vm.isLoggingOut ? 'Logging out...' : 'Logout'),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}