import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/auth_repository.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/stockisi_wordmark.dart';
import 'app_routes.dart';

/// Placeholder Login. Form NIK dan kata sandi dikerjakan di Tahap 2.
///
/// SEMENTARA (Tahap 1): tombol di bawah masuk dengan akun contoh supaya
/// halaman utama bisa dibuka. Dihapus di Tahap 2.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  Future<void> _enterWithSampleAccount() async {
    setState(() => _loading = true);
    try {
      await context.read<AuthRepository>().login('210457', 'stockisi123');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const StockisiWordmark(),
              const SizedBox(height: AppSpace.lg),
              const Text('Login dengan NIK dan kata sandi.',
                  style: AppTextStyles.body),
              const SizedBox(height: AppSpace.sm),
              const Text(
                'Form login dikerjakan di Tahap 2. Untuk sementara, '
                'masuk dengan akun contoh.',
                style: AppTextStyles.bodySecondary,
              ),
              const Spacer(),
              PrimaryActionButton(
                label: 'Masuk dengan akun contoh',
                icon: Icons.login_rounded,
                loading: _loading,
                onPressed: _enterWithSampleAccount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
