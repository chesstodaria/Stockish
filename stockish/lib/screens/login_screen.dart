// lib/screens/login_screen.dart (REPLACE FULL — Remember Login DIMATIKAN, saveUser() dibuang, 18 Agustus 2026)
import 'package:flutter/material.dart';
import '/constants/app_colors.dart';
import '/repositories/auth_repository.dart';
import '../services/session/session_service.dart';
import '../services/post_login_navigator.dart';
import '../services/app_settings_cache.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nikController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthRepository _authRepository = AuthRepository();

  bool _isLoading = false;

  // ⚠️ FIX (3 Agustus 2026) — guard TERPISAH dari _isLoading, dicek & di-set
  // SINKRON di baris pertama _handleLogin(), SEBELUM setState() dipanggil.
  // Root cause bug: `onPressed: _isLoading ? null : _handleLogin` masih
  // bisa ke-trigger 2x kalau operator tap tombol super cepat (network
  // lemot bikin loading indicator kerasa telat muncul, operator tap lagi)
  // — ada celah 1 frame antara tap kedua dengan rebuild yang men-disable
  // tombol dari setState(_isLoading = true) yang PERTAMA. Akibatnya 2
  // request POST /auth/login terkirim hampir bersamaan untuk NIK yang
  // sama — backend "menang" salah satu (invalidate yang duluan, "Digantikan
  // login baru"), tapi kalau response yang PERTAMA balik lebih lambat,
  // app malah pakai token yang sudah keburu diinvalidate. `_isSubmitting`
  // dicek/di-set di baris paling awal, TIDAK menunggu rebuild sama sekali
  // — race window-nya jadi nyaris nol.
  bool _isSubmitting = false;

  Future<void> _handleLogin() async {
    if (_isSubmitting) return;
    _isSubmitting = true;

    try {
      final isValid = _formKey.currentState!.validate();
      if (!isValid) return;

      setState(() => _isLoading = true);

      final user = await _authRepository.login(
        _nikController.text.trim(),
        _passwordController.text,
      );

      // 🆕 (18 Agustus 2026) — load Setting Sesi Mobile (Lock Timer/Polling/
      // Idle-timeout) SEBELUM SessionService().start() — start() langsung
      // baca SessionService.pollInterval saat setup Timer.periodic(), jadi
      // cache ini WAJIB sudah terisi (atau gagal, fallback default) di
      // titik itu. Best-effort — kegagalan di sini TIDAK menghalangi login.
      await AppSettingsCache().loadFromServer(user.token);

      SessionService().start(user);

      // 🔧 (18 Agustus 2026) — Remember Login DIMATIKAN TOTAL, baris
      // `SessionStorageService().saveUser(user)` yang sebelumnya ada di
      // sini DIHAPUS. Sesi TIDAK PERNAH dipersist ke device — tiap buka
      // app, operator WAJIB login ulang manual (Restrukturisasi Auth Tim
      // IT, 05_Decision_Log.md 18 Agustus 2026). Lihat splash_screen.dart
      // (restore logic dihapus total) & session_storage_service.dart
      // (saveUser()/getUser() dihapus, clearUser() dipertahankan untuk
      // purge data lama).

      if (mounted) {
        // 🆕 (5 Agustus 2026) — sebelumnya langsung Navigator.pushReplacement
        // ke DashboardScreen. Sekarang lewat PostLoginNavigator (SHARED
        // dengan SplashScreen sebelumnya — sekarang cuma dipanggil dari
        // sini, satu-satunya jalur masuk sejak Remember Login dimatikan)
        // — cek dulu apakah NIK ini masih pegang lock aktif di dokumen
        // manapun (mis. app di-kill via recent-apps sebelum sempat unlock,
        // sesi baru dibikin lewat login manual ini) — kalau ADA, langsung
        // reclaim & arahkan ke Transaction Detail alih-alih Dashboard.
        await PostLoginNavigator.resolve(context, user);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _isSubmitting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 40),
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(16),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(kPrimaryColor, BlendMode.srcIn),
                  child: Image.asset('assets/images/company_logo.png'),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'StockFlow Mobile',
                style: TextStyle(
                  fontSize: 45,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Welcome back!',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Login untuk mulai transaksi gudang.',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _nikController,
                        decoration: InputDecoration(
                          hintText: 'NIK',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'NIK wajib diisi.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Password wajib diisi.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text('Login', style: TextStyle(fontSize: 16, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('v1.0.0', style: TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}