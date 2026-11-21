import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

/// Tab Profil (layar 13). Placeholder Tahap 1.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Profil',
      stage: 'Tahap 2',
      description: 'Nama, NIK, gudang, dan Logout dengan konfirmasi.',
    );
  }
}
