import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/draft_repository.dart';
import '../../models/operator_profile.dart';
import '../../services/session_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text_styles.dart';

/// Tab Profil (layar 13): nama, NIK, gudang, dan Logout.
///
/// Sebelum logout, app memeriksa draf. Kalau ada draf yang belum
/// disubmit, operator diberi tahu di dialog konfirmasi (CONTEXT 7, babak
/// Keluar). Logout tidak menghapus draf.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;

  Future<void> _logout() async {
    if (_busy) return;
    setState(() => _busy = true);

    Set<String>? drafts;
    try {
      drafts = await context.read<DraftRepository>().getDocumentNumbersWithDraft();
    } catch (_) {
      drafts = null; // Tidak bisa diperiksa, tetap boleh logout.
    }
    if (!mounted) return;
    // Spinner hanya saat memeriksa draf dan saat logout, tidak selama
    // dialog terbuka.
    setState(() => _busy = false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _LogoutDialog(draftNumbers: drafts),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _busy = true);
    // Setelah sesi kosong, SessionGuard di halaman utama mengarahkan ke
    // Login dan mengosongkan tumpukan layar.
    await context.read<SessionController>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final operator = context.watch<SessionController>().operator;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.screen),
              children: [
                if (operator != null) ...[
                  _Header(operator: operator),
                  const SizedBox(height: AppSpace.lg),
                  _InfoCard(operator: operator),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.screen, 0, AppSpace.screen, AppSpace.lg),
            child: SizedBox(
              width: double.infinity,
              height: AppSize.primaryButton,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error, width: 1.5),
                ),
                onPressed: _busy ? null : _logout,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: AppSize.iconSm,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout_rounded),
                label: const Text('Logout'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final OperatorProfile operator;
  const _Header({required this.operator});

  String get _initials {
    final parts = operator.name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.navy,
          child: Text(
            _initials,
            style: AppTextStyles.title.copyWith(color: AppColors.onNavy),
          ),
        ),
        const SizedBox(width: AppSpace.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(operator.name, style: AppTextStyles.headline),
              const SizedBox(height: AppSpace.xs),
              const Text('Operator gudang', style: AppTextStyles.bodySecondary),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final OperatorProfile operator;
  const _InfoCard({required this.operator});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.badge_outlined,
            label: 'NIK',
            value: operator.nik,
          ),
          const Divider(indent: AppSpace.lg, endIndent: AppSpace.lg),
          _InfoRow(
            icon: Icons.warehouse_outlined,
            label: 'Gudang',
            value: operator.warehouseName,
            detail: 'Kode ${operator.warehouseCode}',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? detail;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodySecondary),
                const SizedBox(height: 2),
                Text(value, style: AppTextStyles.bodyStrong),
                if (detail != null)
                  Text(detail!, style: AppTextStyles.bodySecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Konfirmasi logout. Isinya menyesuaikan keadaan draf:
/// tidak ada draf, ada draf (disebutkan nomor dokumennya), atau draf tidak
/// bisa diperiksa ([draftNumbers] null).
class _LogoutDialog extends StatelessWidget {
  final Set<String>? draftNumbers;
  const _LogoutDialog({required this.draftNumbers});

  @override
  Widget build(BuildContext context) {
    final drafts = draftNumbers;
    final hasDrafts = drafts != null && drafts.isNotEmpty;
    final sorted = hasDrafts ? (drafts.toList()..sort()) : const <String>[];

    final Widget content;
    if (hasDrafts) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${sorted.length} dokumen masih punya draf:',
              style: AppTextStyles.body),
          const SizedBox(height: AppSpace.sm),
          for (final number in sorted)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.edit_note_rounded,
                      size: AppSize.iconSm, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpace.sm),
                  Text(number, style: AppTextStyles.bodyStrong),
                ],
              ),
            ),
          const SizedBox(height: AppSpace.md),
          const Text(
            'Draf tidak dihapus. Anda bisa melanjutkannya setelah login '
            'lagi dengan akun yang sama.',
            style: AppTextStyles.bodySecondary,
          ),
        ],
      );
    } else if (drafts == null) {
      content = const Text(
        'Draf tidak bisa diperiksa saat ini. Draf yang sudah tersimpan '
        'tidak akan dihapus.',
        style: AppTextStyles.body,
      );
    } else {
      content = const Text(
        'Anda perlu login lagi dengan NIK dan kata sandi untuk memakai '
        'aplikasi.',
        style: AppTextStyles.body,
      );
    }

    return AlertDialog(
      title: Text(
          hasDrafts ? 'Ada draf yang belum disubmit' : 'Logout dari Stockisi?'),
      content: SingleChildScrollView(child: content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(AppSize.minTouch * 2, AppSize.minTouch),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(hasDrafts ? 'Tetap logout' : 'Logout'),
        ),
      ],
    );
  }
}
