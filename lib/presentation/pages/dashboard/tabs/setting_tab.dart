import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_provider.dart';
import 'package:pos_mobile/presentation/widgets/branch_switch_sheet.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import '../../../pages/shifts/shift_page.dart';
import '../../../pages/settings/printer_settings_page.dart';
import '../../../pages/attendance/attendance_page.dart';

class SettingTab extends ConsumerWidget {
  const SettingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);
    final role = auth.role;
    final canAttend = hasFeature(role, AppFeature.attendance);
    final canShift = hasFeature(role, AppFeature.shift);
    final currentBranch = ref.watch(currentBranchProvider);
    final accent = theme.colorScheme.primary;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return ListView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset + 96),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withOpacity(0.20)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Atur Bisnis Anda",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Kelola data master dan preferensi aplikasi.",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.settings_outlined, color: accent, size: 28),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingMenuCard(
          title: "Ganti Cabang",
          subtitle: currentBranch?.name ?? "Pilih cabang aktif",
          icon: Icons.store_outlined,
          color: accent,
          onTap: () => showBranchSwitchSheet(context),
        ),
        if (canAttend) ...[
          const SizedBox(height: 16),
          _SettingMenuCard(
            title: "Absensi",
            subtitle: "Absen masuk & pulang pakai foto dan lokasi",
            icon: Icons.fingerprint,
            color: accent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AttendancePage()),
              );
            },
          ),
        ],
        if (canShift) ...[
          const SizedBox(height: 16),
          _SettingMenuCard(
            title: "Shift Kasir",
            subtitle: "Buka / tutup shift & rekap kas",
            icon: Icons.point_of_sale_outlined,
            color: accent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShiftPage()),
              );
            },
          ),
        ],
        const SizedBox(height: 16),
        _SettingMenuCard(
          title: "Perangkat Cetak",
          subtitle: "Printer default & cetak otomatis",
          icon: Icons.print_outlined,
          color: accent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrinterSettingsPage()),
            );
          },
        ),
        const SizedBox(height: 16),
        _SettingMenuCard(
          title: "Logout",
          subtitle: "Keluar dari akun saat ini",
          icon: Icons.logout,
          color: AppTheme.danger,
          onTap: () async {
            await ref.read(authProvider.notifier).logout();
          },
        ),
      ],
    );
  }
}

class _SettingMenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SettingMenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.bgLight,
                border: Border.all(color: AppTheme.borderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.chevron_right,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
