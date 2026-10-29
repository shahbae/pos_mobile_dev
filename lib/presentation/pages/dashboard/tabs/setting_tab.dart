import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/presentation/pages/offline/offline_queue_page.dart';
import 'package:pos_mobile/presentation/widgets/offline_hold.dart';
import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_provider.dart';
import 'package:pos_mobile/presentation/providers/duty_provider.dart';
import 'package:pos_mobile/presentation/providers/payroll_provider.dart';
import 'package:pos_mobile/presentation/widgets/branch_switch_sheet.dart';
import 'package:pos_mobile/presentation/widgets/app_version_card.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import '../../../pages/shifts/shift_page.dart';
import '../../../pages/settings/printer_settings_page.dart';
import '../../../pages/settings/qris_settings_page.dart';
import '../../../pages/attendance/attendance_page.dart';
import '../../../pages/attendance/leave_out_list_page.dart';
import '../../../pages/attendance/on_duty_page.dart';
import '../../../pages/profile/profile_page.dart';
import '../../../pages/schedules/my_schedule_page.dart';
import '../../../pages/kitchen/kitchen_display_page.dart';
import '../../../pages/payroll/cash_loan_page.dart';
import '../../../pages/payroll/my_loans_page.dart';
import '../../../pages/payroll/payslip_list_page.dart';
import '../../../pages/reminders/reminder_list_page.dart';
import '../../../pages/help/help_ticket_list_page.dart';

class SettingTab extends ConsumerWidget {
  const SettingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);
    final role = auth.role;
    final canAttend = hasFeature(role, AppFeature.attendance);
    // Shift kasir ditutup untuk karyawan yang hari ini bertugas penyaji.
    final canShift = ref.watch(todayFeaturesProvider).contains(AppFeature.shift);
    final canMonitorKitchen = hasFeature(role, AppFeature.kitchenDisplay);
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
        if (canMonitorKitchen) ...[
          const SizedBox(height: 16),
          _SettingMenuCard(
            title: "Monitoring Pesanan",
            subtitle: auth.branchId == null
                ? "Pilih cabang aktif dulu"
                : "Layar dapur: pesanan masuk realtime",
            icon: Icons.ramen_dining_outlined,
            color: accent,
            onTap: () {
              // BE mengunci stream ke satu cabang. Owner yang belum switch
              // cabang tidak punya branch_id, jadi diarahkan memilih dulu.
              if (auth.branchId == null) {
                showBranchSwitchSheet(context);
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KitchenDisplayPage()),
              );
            },
          ),
        ],
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
        if (canReceiveReminders(auth.held)) ...[
          const SizedBox(height: 16),
          _SettingMenuCard(
            title: "Reminder",
            subtitle: "Catatan & permintaan foto dari SPV atau leader",
            icon: Icons.campaign_outlined,
            color: accent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReminderListPage()),
            ),
          ),
        ],
        if (canUseHelpTickets(auth.held)) ...[
          const SizedBox(height: 16),
          _SettingMenuCard(
            title: "Bantuan",
            subtitle: "Tiket ke SPV atau finance",
            icon: Icons.support_agent,
            color: accent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpTicketListPage()),
            ),
          ),
        ],
        if (canAttend) ...[
          const SizedBox(height: 16),
          _SettingMenuCard(
            title: "Jadwal Saya",
            subtitle: "Shift, tugas, dan lokasi kerja",
            icon: Icons.calendar_month_outlined,
            color: accent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MySchedulePage()),
            ),
          ),
        ],
        if (canMarkOvertime(auth.held)) ...[
          const SizedBox(height: 16),
          _SettingMenuCard(
            title: "Yang Bertugas & Lembur",
            subtitle: "Siapa yang sudah absen masuk, tandai lembur",
            icon: Icons.groups_outlined,
            color: accent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OnDutyPage()),
            ),
          ),
        ],
        if (canSeeLeaveOuts(auth.held)) ...[
          const SizedBox(height: 16),
          _SettingMenuCard(
            title: "Izin Keluar",
            subtitle: "Riwayat keluar sebentar dari outlet",
            icon: Icons.directions_walk,
            color: accent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaveOutListPage()),
            ),
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
        // Serah pinjaman tunai: ikut menu Shift Kasir — yang menyerahkan harus
        // memegang laci shift yang sedang buka (BE menolak penyaji dan yang
        // belum buka shift).
        if (canShift && canHandOutLoan(auth.held) && auth.branchId != null) ...[
          const SizedBox(height: 16),
          _SettingMenuCard(
            title: "Pinjaman Tunai",
            subtitle: switch (ref.watch(cashPendingLoansProvider).valueOrNull?.length) {
              null || 0 => "Serahkan pinjaman karyawan dari laci",
              final n => "$n menunggu diserahkan dari laci",
            },
            icon: Icons.payments_outlined,
            color: accent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CashLoanPage()),
            ),
          ),
        ],
        if (canManageBranchQris(role) && auth.branchId != null) ...[
          const SizedBox(height: 16),
          _SettingMenuCard(
            title: "QRIS Cabang",
            subtitle: "Mode pembayaran & QR statis cabang",
            icon: Icons.qr_code_2,
            color: accent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QrisSettingsPage(
                    branchId: auth.branchId!,
                    branchName: currentBranch?.name,
                  ),
                ),
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
        if (hasFeature(auth.role, AppFeature.pos)) ...[
          const SizedBox(height: 16),
          _SettingMenuCard(
            title: "Penjualan Offline",
            subtitle: "Penjualan yang dibuat saat jaringan putus",
            icon: Icons.cloud_off_outlined,
            color: accent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OfflineQueuePage()),
              );
            },
          ),
        ],
        if (canUsePayroll(auth.held)) ...[
          const SizedBox(height: 16),
          _SettingMenuCard(
            title: "Slip Gaji",
            subtitle: "Rincian gaji tiap bulan, PDF, komplain",
            icon: Icons.receipt_long_outlined,
            color: accent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PayslipListPage()),
            ),
          ),
          const SizedBox(height: 16),
          _SettingMenuCard(
            title: "Pinjaman",
            subtitle: "Ajukan pinjaman dan lihat statusnya",
            icon: Icons.request_quote_outlined,
            color: accent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyLoansPage()),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _SettingMenuCard(
          title: "Profil",
          subtitle: "Data diri, foto, ganti password",
          icon: Icons.person_outline,
          color: accent,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfilePage()),
          ),
        ),
        const SizedBox(height: 16),
        const AppVersionCard(),
        const SizedBox(height: 16),
        _SettingMenuCard(
          title: "Logout",
          subtitle: "Keluar dari akun saat ini",
          icon: Icons.logout,
          color: AppTheme.danger,
          onTap: () async {
            if (!await ensureNothingUnsent(context, ref, action: 'Logout')) return;
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
