import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/presentation/pages/dashboard/menu_layout.dart';
import 'package:pos_mobile/presentation/pages/dashboard/menu_tiles.dart';
import 'package:pos_mobile/presentation/pages/profile/profile_page.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/widgets/app_version_card.dart';
import 'package:pos_mobile/presentation/widgets/notification_readiness_card.dart';
import 'package:pos_mobile/presentation/widgets/offline_hold.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Setting (ikon gir kanan atas, layout baru revisi owner 26 Nov 2026):
/// Perangkat cetak, Produk, (Ganti Cabang & QRIS Cabang untuk owner/SPV),
/// kesiapan notifikasi HP, Versi aplikasi, Ganti password, Log out.
class SettingPage extends ConsumerWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Setting'), centerTitle: true),
      body: MenuList(
        keys: settingMenu(ref.watch(menuAccessProvider)),
        footer: [
          // Pengaturan HP yang bisa membuat alarm foto tak berbunyi.
          const NotificationReadinessCard(),
          const AppVersionCard(),
          _OutlinedAction(
            label: 'Ganti password',
            icon: Icons.lock_outline,
            color: AppTheme.brandGreenDark,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
            ),
          ),
          _OutlinedAction(
            label: 'Log out',
            icon: Icons.logout,
            color: AppTheme.danger,
            onPressed: () async {
              if (!await ensureNothingUnsent(context, ref, action: 'Logout')) return;
              // MaterialApp dibangun ulang saat status login berubah, jadi
              // halaman yang ditumpuk ini ikut hilang dan layar login tampil.
              await ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  const _OutlinedAction({required this.label, required this.icon, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: color),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        side: BorderSide(color: color, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        backgroundColor: Colors.white,
      ),
    );
  }
}
