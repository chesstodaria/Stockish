import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/draft_repository.dart';
import '../../models/operator_profile.dart';
import '../../services/session_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_header.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/pressable.dart';
import '../../widgets/section_header.dart';

/// Tab Profil (layar 13): nama, NIK, gudang, dan Logout.
///
/// Sebelum logout, app memeriksa draf. Kalau ada draf yang belum disubmit,
/// operator diberi tahu di dialog konfirmasi (CONTEXT 7, babak Keluar).
/// Logout tidak menghapus draf.
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
      drafts =
          await context.read<DraftRepository>().getDocumentNumbersWithDraft();
    } catch (_) {
      drafts = null; // Tidak bisa diperiksa, tetap boleh logout.
    }
    if (!mounted) return;
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
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.screen,
          AppSpace.md,
          AppSpace.screen,
          AppSpace.xl,
        ),
        children: [
          const AppHeader(title: 'Profil'),
          const SizedBox(height: AppSpace.lg),
          if (operator != null) ...[
            _IdentityCard(operator: operator),
            const SizedBox(height: AppSpace.xl),
            const SectionHeader('Akun'),
            const SizedBox(height: AppSpace.sm),
            GroupedList(
              children: [
                GroupedRow(child: _InfoRow(
                  label: 'Gudang',
                  value: '${operator.warehouseCode} · '
                      '${operator.warehouseName}',
                )),
                GroupedRow(child: _InfoRow(
                  label: 'Peran',
                  value: 'Operator gudang',
                )),
                GroupedRow(child: _InfoRow(label: 'NIK', value: operator.nik)),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            _LogoutButton(busy: _busy, onPressed: _logout),
            const SizedBox(height: AppSpace.lg),
            Text(
              'Draf yang belum disubmit akan diberitahukan sebelum keluar.',
              style: AppTextStyles.code,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final OperatorProfile operator;

  const _IdentityCard({required this.operator});

  String get _initials {
    final parts = operator.name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg - 2),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.navy,
              shape: BoxShape.circle,
            ),
            child: Text(
              _initials,
              style: AppTextStyles.bodyStrong.copyWith(
                color: AppColors.onNavy,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.md + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(operator.name, style: AppTextStyles.title),
                const SizedBox(height: 2),
                Text('NIK ${operator.nik}', style: AppTextStyles.code),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: AppTextStyles.bodySecondary),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodyStrong,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onPressed;

  const _LogoutButton({required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: busy ? null : onPressed,
      child: Container(
        height: AppSize.primaryButton,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg - 2),
          border: Border.all(color: AppColors.border),
        ),
        child: busy
            ? const SizedBox.square(
                dimension: AppSize.iconSm,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                'Logout',
                style: AppTextStyles.button.copyWith(
                  color: AppColors.errorFg,
                ),
              ),
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
