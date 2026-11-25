import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/repositories/repositories.dart';
import '../data/repository_exceptions.dart';
import '../services/connectivity_status.dart';
import '../services/device_id_store.dart';
import '../services/session_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import '../widgets/inline_error_banner.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/stockisi_wordmark.dart';
import 'app_routes.dart';

/// Login dengan NIK dan kata sandi.
///
/// Kalau gagal, pesan tampil di form dan NIK yang sudah diketik tidak
/// dihapus (CONTEXT 7, babak Masuk). Kata sandi dikosongkan kalau ditolak,
/// dan dipertahankan kalau gagalnya karena koneksi.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nik = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _obscure = true;
  bool _loading = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _nik.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<SessionController>().login(_nik.text, _password.text);
      if (!mounted) return;
      context.read<ConnectivityStatus>().reportOnline();

      // Satu NIK hanya boleh aktif di satu perangkat.
      final devices = context.read<SessionDeviceRepository>();
      final deviceId = await context.read<DeviceIdStore>().read();
      final nik = _nik.text.trim();
      final registered = await devices.register(nik, deviceId);
      if (!mounted) return;
      if (!registered) {
        final force = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Akun sedang dipakai'),
            content: const Text(
              'NIK ini sedang aktif di perangkat lain. Kalau Anda '
              'melanjutkan, sesi di perangkat itu akan berakhir.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Gunakan di sini'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (force != true) {
          await context.read<SessionController>().logout();
          if (!mounted) return;
          setState(() => _loading = false);
          return;
        }
        await devices.register(nik, deviceId, force: true);
        if (!mounted) return;
      }

      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
        _password.clear();
        // Kolom sandi sengaja dikosongkan; jangan langsung ditandai
        // "wajib diisi" di samping pesan penolakan.
        _submitted = false;
      });
      // Fokus setelah kolom aktif lagi di frame berikutnya.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _passwordFocus.requestFocus());
    } on RepositoryException catch (e) {
      if (!mounted) return;
      if (e is DataUnavailableException) {
        context.read<ConnectivityStatus>().reportOffline();
      }
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submitted
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: AutofillGroup(child: _buildContent()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const Align(
          alignment: Alignment.centerLeft,
          child: StockisiWordmark(),
        ),
        const SizedBox(height: AppSpace.xxl),
        const Text('Masuk', style: AppTextStyles.headline),
        const SizedBox(height: AppSpace.xs),
        const Text(
          'Gunakan NIK dan kata sandi akun gudang Anda.',
          style: AppTextStyles.bodySecondary,
        ),
        const SizedBox(height: AppSpace.xl),
        TextFormField(
          controller: _nik,
          enabled: !_loading,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppTextStyles.body,
          decoration: const InputDecoration(
            labelText: 'NIK',
            prefixIcon: Icon(Icons.badge_outlined),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
              borderSide: BorderSide(color: AppColors.navy, width: 1.5),
            ),
          ),
          onChanged: (_) => _clearError(),
          onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'NIK wajib diisi.' : null,
        ),
        const SizedBox(height: AppSpace.lg),
        TextFormField(
          controller: _password,
          focusNode: _passwordFocus,
          enabled: !_loading,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          style: AppTextStyles.body,
          decoration: InputDecoration(
            labelText: 'Kata sandi',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            filled: true,
            fillColor: AppColors.surface,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
              borderSide: BorderSide(color: AppColors.navy, width: 1.5),
            ),
            suffixIcon: IconButton(
              tooltip:
                  _obscure ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
              icon: Icon(_obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              color: AppColors.textSecondary,
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          onChanged: (_) => _clearError(),
          onFieldSubmitted: (_) => _submit(),
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Kata sandi wajib diisi.' : null,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpace.lg),
          InlineErrorBanner(_error!),
        ],
        const Spacer(),
        const SizedBox(height: AppSpace.xl),
        PrimaryActionButton(
          label: 'Masuk',
          icon: Icons.login_rounded,
          loading: _loading,
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpace.lg),
        const Text(
          'Hubungi admin gudang bila akun Anda belum aktif.',
          style: AppTextStyles.code,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpace.lg),
      ],
    );
  }
}
