import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import '../../../pages/branches/branch_list_page.dart';
import '../../../pages/shifts/shift_page.dart';
import '../../../pages/suppliers/supplier_list_page.dart';
import '../../../pages/customers/customer_list_page.dart';
import '../../../pages/employees/employee_list_page.dart';

class SettingTab extends ConsumerWidget {
  const SettingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);
    final role = auth.role;
    // Hak akses sesuai role BE: owner|supervisor|leader|finance|kasir|karyawan|produksi
    final canManageEmployees = role == 'owner' || role == 'supervisor';
    final canManageBranches = role == 'owner';
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
          title: "Pemasok",
          subtitle: "Kelola daftar pemasok",
          icon: Icons.factory_outlined,
          color: accent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupplierListPage()),
            );
          },
        ),
        const SizedBox(height: 16),
        _SettingMenuCard(
          title: "Pelanggan",
          subtitle: "Kelola daftar pelanggan",
          icon: Icons.people_alt_outlined,
          color: accent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerListPage()),
            );
          },
        ),
        if (canManageEmployees) ...[
          const SizedBox(height: 16),
          _SettingMenuCard(
            title: "Karyawan",
            subtitle: "Kelola akun karyawan",
            icon: Icons.badge_outlined,
            color: accent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EmployeeListPage()),
              );
            },
          ),
        ],
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
        if (canManageBranches) ...[
          const SizedBox(height: 16),
          _SettingMenuCard(
            title: "Cabang",
            subtitle: "Kelola cabang & catatan nota",
            icon: Icons.store_mall_directory_outlined,
            color: accent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BranchListPage()),
              );
            },
          ),
        ],
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
