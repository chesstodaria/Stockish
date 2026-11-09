import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/activity_log.dart';
import '../repositories/activity_log_repository.dart';
import '../repositories/auth_repository.dart';
import '../services/database/database_service.dart';
import '../services/session/session_service.dart';
import '../services/session/session_storage_service.dart';

/// ViewModel untuk ProfileScreen.
///
/// Sebelumnya ProfileScreen sengaja dibangun TANPA ViewModel (lihat
/// 02_Feature_Profile.md) karena statenya cuma 1x fetch tanpa interaksi
/// lanjutan. Sekarang di-refactor ke MVVM sekaligus menambah kapabilitas
/// baru (pull-to-refresh) — state riwayat aktivitas jadi lebih dari
/// sekadar "fetch sekali", jadi ChangeNotifier sudah relevan.
///
/// Pola sama dengan ReferenceDocumentListViewModel: BUKAN singleton,
/// 1 instance per Screen, dibuat sekali di initState() milik Screen.
class ProfileViewModel extends ChangeNotifier {
  final ActivityLogRepository _repository = ActivityLogRepository();
  final AuthRepository _authRepository = AuthRepository();
  final User user;

  ProfileViewModel({required this.user});

  List<ActivityLog> _logs = [];
  bool _isLoading = true;
  bool _hasError = false;
  DateTime? _lastRefreshTime;

  // 🆕 (12 Agustus 2026) — guard double-tap tombol Logout. Ditemukan saat
  // testing Audit Log Offline Queue: tap Logout 2x cepat (mis. saat
  // koneksi lambat/banner "Koneksi terputus" tampil, operator kira
  // tap pertama belum kena) memicu 2× logout()/addLog() terpisah.
  // Bukan bug fatal (queue tetap aman, tidak ada data hilang), tapi
  // tombol seharusnya disable selama proses berjalan — pola sama
  // isGenerating/isSubmittingNetworkPrint di PrintQrViewModel.
  bool _isLoggingOut = false;

  List<ActivityLog> get logs => _logs;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  DateTime? get lastRefreshTime => _lastRefreshTime;
  bool get isLoggingOut => _isLoggingOut;

  /// Dipanggil sekali di initState() Screen. Isi logic sama persis dengan
  /// _logsFuture lama, cuma dipindah ke sini + ditambah error handling
  /// (FutureBuilder lama tidak punya state error eksplisit).
  Future<void> loadLogs() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      _logs = await _repository.getLogsByNik(user.nik, user.token);
      _lastRefreshTime = DateTime.now();
    } catch (_) {
      _hasError = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Dipanggil dari RefreshIndicator (kapabilitas baru, pull-to-refresh).
  /// Sengaja panggil ulang loadLogs() — fetch-nya idempotent (selalu ambil
  /// list terbaru dari repository), tidak perlu logic terpisah.
  Future<void> refresh() => loadLogs();

  /// Urus service call logout (invalidate sesi ke backend + stop polling
  /// Force Logout + hapus sesi Remember Login tersimpan). Dialog konfirmasi
  /// & navigasi ke LoginScreen TETAP tanggung jawab Screen (butuh
  /// BuildContext) — pemisahan sama seperti lockDocument() di
  /// ReferenceDocumentListViewModel yang murni urus data/service call,
  /// Screen yang urus UI/navigasi.
  ///
  /// 23 Juli 2026 — GAP DITEMUKAN & DIFIX: sebelumnya method ini cuma
  /// stop() + clearUser() (murni lokal), sesi backend tidak pernah
  /// diinvalidate saat logout manual. Sekarang panggil
  /// AuthRepository().logout(token) DULUAN (best-effort, lihat
  /// auth_repository.dart) — urutan tidak krusial (semuanya idempotent),
  /// tapi ditaruh di awal supaya token masih pasti ada saat dipakai
  /// (SessionStorageService.clearUser() belum menghapusnya di titik ini).
  ///
  /// 🆕 (12 Agustus 2026) — guard _isLoggingOut ditambah DI DALAM method
  /// ini (bukan cuma disable tombol di Screen) — 2 lapis pertahanan,
  /// konsisten prinsip project (lihat guard hapus-akun-sendiri 11 Agustus).
  /// Guard di sini melindungi dari pemanggilan manapun (termasuk kalau
  /// nanti ada titik panggil lain selain tombol Screen), disable tombol
  /// di Screen murni UX (feedback visual + cegah tap fisik berulang).
  Future<void> logout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    notifyListeners();

    try {
      await _authRepository.logout(user.token);
      SessionService().stop();
      await SessionStorageService().clearUser();
    } finally {
      _isLoggingOut = false;
      // Tidak notifyListeners() di sini secara sengaja bisa jadi masalah
      // kalau Screen tidak langsung dispose/navigate setelah logout()
      // selesai — tapi caller (_handleLogout di Screen) SELALU navigasi
      // pergi (pushAndRemoveUntil ke LoginScreen) begitu logout() return,
      // jadi notify di sini aman tidak berdampak (widget sudah unmount).
      notifyListeners();
    }
  }

  /// 🆕 11 Agustus 2026 — Export Log Diagnostik Auth/Sesi.
  ///
  /// Format isi tabel `auth_debug_log` (SQLite lokal, lihat
  /// DatabaseService) jadi teks siap-share, dipicu long-press avatar di
  /// ProfileScreen (sengaja tersembunyi, bukan tombol biasa — biar
  /// operator gudang normal tidak bingung ada fitur ini). Tujuan: bantu
  /// investigasi "kick sesi misterius" (02_Feature_Authentication.md
  /// Known Issues, hipotesis ke-3) tanpa perlu USB/adb ke tablet
  /// lapangan — operator tinggal share hasilnya ke tim IT lewat WA/Email.
  Future<String> exportAuthDebugLog() {
    return DatabaseService().exportAuthLogsAsText();
  }
}