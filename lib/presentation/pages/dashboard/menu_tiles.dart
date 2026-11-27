import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/utils/currency.dart';
import 'package:pos_mobile/data/models/kpi_model.dart';
import 'package:pos_mobile/presentation/pages/allowance/my_allowance_page.dart';
import 'package:pos_mobile/presentation/pages/attendance/attendance_page.dart';
import 'package:pos_mobile/presentation/pages/attendance/leave_out_card.dart';
import 'package:pos_mobile/presentation/pages/attendance/leave_out_list_page.dart';
import 'package:pos_mobile/presentation/pages/attendance/on_duty_page.dart';
import 'package:pos_mobile/presentation/pages/attendance/work_gate.dart';
import 'package:pos_mobile/presentation/pages/dashboard/daily_tasks_page.dart';
import 'package:pos_mobile/presentation/pages/dashboard/menu_layout.dart';
import 'package:pos_mobile/presentation/pages/expenses/expense_list_page.dart';
import 'package:pos_mobile/presentation/pages/help/help_ticket_list_page.dart';
import 'package:pos_mobile/presentation/pages/kitchen/kitchen_display_page.dart';
import 'package:pos_mobile/presentation/pages/kpi/cash_deposit_page.dart';
import 'package:pos_mobile/presentation/pages/kpi/directives_page.dart';
import 'package:pos_mobile/presentation/pages/kpi/inspection_list_page.dart';
import 'package:pos_mobile/presentation/pages/kpi/kpi_widgets.dart';
import 'package:pos_mobile/presentation/pages/kpi/my_kpi_page.dart';
import 'package:pos_mobile/presentation/pages/kpi/photo_checklist_page.dart';
import 'package:pos_mobile/presentation/pages/offline/offline_queue_page.dart';
import 'package:pos_mobile/presentation/pages/payroll/cash_loan_page.dart';
import 'package:pos_mobile/presentation/pages/payroll/my_loans_page.dart';
import 'package:pos_mobile/presentation/pages/payroll/payslip_list_page.dart';
import 'package:pos_mobile/presentation/pages/plastic_stock/plastic_stock_movement_page.dart';
import 'package:pos_mobile/presentation/pages/plastic_stock/plastic_stock_page.dart';
import 'package:pos_mobile/presentation/pages/products/product_list_page.dart';
import 'package:pos_mobile/presentation/pages/reminders/reminder_list_page.dart';
import 'package:pos_mobile/presentation/pages/reports/daily_report_page.dart';
import 'package:pos_mobile/presentation/pages/reports/leader_daily_report_page.dart';
import 'package:pos_mobile/presentation/pages/reports/payments_report_page.dart';
import 'package:pos_mobile/presentation/pages/reports/stock_alerts_report_page.dart';
import 'package:pos_mobile/presentation/pages/returns/branch_return_page.dart';
import 'package:pos_mobile/presentation/pages/schedules/my_schedule_page.dart';
import 'package:pos_mobile/presentation/pages/sedotan_stock/sedotan_stock_movement_page.dart';
import 'package:pos_mobile/presentation/pages/sedotan_stock/sedotan_stock_page.dart';
import 'package:pos_mobile/presentation/pages/settings/printer_settings_page.dart';
import 'package:pos_mobile/presentation/pages/settings/qris_settings_page.dart';
import 'package:pos_mobile/presentation/pages/shifts/shift_page.dart';
import 'package:pos_mobile/presentation/pages/shipments/shipment_list_page.dart';
import 'package:pos_mobile/presentation/pages/sop/sop_page.dart';
import 'package:pos_mobile/presentation/pages/stock_audits/stock_audit_list_page.dart';
import 'package:pos_mobile/presentation/pages/stock_levels/stock_level_page.dart';
import 'package:pos_mobile/presentation/pages/stock_movements/stock_movement_list_page.dart';
import 'package:pos_mobile/presentation/pages/stock_requests/stock_request_list_page.dart';
import 'package:pos_mobile/presentation/pages/topping_stock/topping_stock_movement_page.dart';
import 'package:pos_mobile/presentation/pages/topping_stock/topping_stock_page.dart';
import 'package:pos_mobile/presentation/pages/transactions/transaction_history_page.dart';
import 'package:pos_mobile/presentation/pages/waste/waste_form_page.dart';
import 'package:pos_mobile/presentation/providers/allowance_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_provider.dart';
import 'package:pos_mobile/presentation/providers/duty_provider.dart';
import 'package:pos_mobile/presentation/providers/kpi_provider.dart';
import 'package:pos_mobile/presentation/providers/payroll_provider.dart';
import 'package:pos_mobile/presentation/providers/shipment_provider.dart';
import 'package:pos_mobile/presentation/widgets/branch_switch_sheet.dart';
import 'package:pos_mobile/presentation/widgets/setting_menu_card.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Bahan menu dari akun yang masuk dan tugas hari ini.
final menuAccessProvider = Provider<MenuAccess>((ref) {
  final auth = ref.watch(authProvider);
  return MenuAccess(
    today: ref.watch(todayFeaturesProvider),
    role: auth.role,
    held: auth.held,
    hasBranch: auth.branchId != null,
  );
});

/// Nama pendek menu Tugas setiap hari, untuk keterangan kartunya di Laporan.
const _dailyTaskShortNames = {
  MenuKey.monitoringPesanan: 'monitoring pesanan',
  MenuKey.ceklisFoto: 'ceklis foto',
  MenuKey.reminder: 'reminder',
  MenuKey.setoran: 'setoran',
  MenuKey.bantuan: 'bantuan',
  MenuKey.arahanSpv: 'arahan SPV',
  MenuKey.sidak: 'sidak',
};

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Daftar kartu menu dengan jarak seragam, dipakai semua tab layout baru.
class MenuList extends StatelessWidget {
  final List<MenuKey> keys;
  final List<Widget> header;
  final List<Widget> footer;
  const MenuList({super.key, required this.keys, this.header = const [], this.footer = const []});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final children = <Widget>[...header, for (final k in keys) MenuTile(k), ...footer];
    return ListView.separated(
      // Bisa ditarik untuk muat ulang walau isinya pendek (tab Profil).
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset + 96),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => children[i],
    );
  }
}

/// Satu kartu menu. Menu kerja (Catat Waste, Retur Stok, Audit Stok, Ceklis
/// Foto, Shift Kasir) tetap menagih absen masuk saat diketuk (revisi owner
/// 26 Nov 2026 langkah 2), di mana pun letaknya sekarang.
class MenuTile extends ConsumerWidget {
  final MenuKey menu;
  const MenuTile(this.menu, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    // Menu kerja: wajib sudah absen masuk (dan posisi kasir untuk Kasir).
    Future<void> openOnDuty(Widget page, {bool cashier = false}) async {
      if (!await ensureOnDuty(context, ref, cashier: cashier) || !context.mounted) return;
      open(page);
    }

    SettingMenuCard card(String title, String subtitle, IconData icon, VoidCallback? onTap,
            {int badge = 0, Widget? trailing}) =>
        SettingMenuCard(
          title: title,
          subtitle: subtitle,
          icon: icon,
          onTap: onTap,
          badge: badge,
          trailing: trailing,
        );

    switch (menu) {
      // ── Stok ──
      case MenuKey.catatWaste:
        return card('Catat Waste', 'Barang yang dibuang (tumpah, basi, rusak) + foto',
            Icons.delete_sweep_outlined, () => openOnDuty(const WasteFormPage()));
      case MenuKey.returStok:
        return card('Retur Stok', 'Kirim barang balik ke gudang tanpa hitung fisik',
            Icons.assignment_return_outlined, () => openOnDuty(const BranchReturnPage()));
      case MenuKey.permintaanStok:
        return card('Permintaan Stok', 'Minta barang yang habis ke gudang', Icons.local_shipping_outlined,
            () => open(const StockRequestListPage()));
      case MenuKey.kirimanGudang:
        // Kiriman yang sudah sampai tapi belum diterima berarti stoknya belum
        // bertambah; angkanya ditaruh di menunya supaya tak perlu diingat.
        return card('Kiriman Gudang', 'Status dikirim & terima barang kiriman', Icons.inbox_outlined,
            () => open(const ShipmentListPage()),
            badge: ref.watch(pendingShipmentCountProvider));
      case MenuKey.stokMenipis:
        return card('Stok Menipis', 'Barang yang stoknya di bawah batasnya', Icons.warning_amber_rounded,
            () => open(const StockAlertsReportPage()));
      case MenuKey.auditStok:
        return card('Audit Stok', 'Hitung fisik & sesuaikan stok', Icons.fact_check_outlined,
            () => openOnDuty(const StockAuditListPage()));
      case MenuKey.stokMaterial:
        return card('Stok Material', 'Lihat stok, harus sama dengan fisik', Icons.inventory_outlined,
            () => open(const StockLevelPage()));
      case MenuKey.stokTopping:
        return card('Stok Topping', 'Lihat stok, harus sama dengan fisik', Icons.icecream_outlined,
            () => open(const ToppingStockPage()));
      case MenuKey.stokPlastik:
        return card('Stok Plastik', 'Lihat stok, harus sama dengan fisik', Icons.shopping_bag_outlined,
            () => open(const PlasticStockPage()));
      case MenuKey.stokSedotan:
        return card('Stok Sedotan', 'Lihat stok, harus sama dengan fisik', Icons.local_drink_outlined,
            () => open(const SedotanStockPage()));
      case MenuKey.mutasiMaterial:
        return card('Riwayat Mutasi Stok', 'Keluar / masuk stok material', Icons.history_outlined,
            () => open(const StockMovementListPage()));
      case MenuKey.mutasiTopping:
        return card('Riwayat Mutasi Stok Topping', 'Keluar / masuk stok topping', Icons.history_outlined,
            () => open(const ToppingStockMovementPage()));
      case MenuKey.mutasiPlastik:
        return card('Riwayat Mutasi Stok Plastik', 'Keluar / masuk stok plastik', Icons.history_outlined,
            () => open(const PlasticStockMovementPage()));
      case MenuKey.mutasiSedotan:
        return card('Riwayat Mutasi Stok Sedotan', 'Keluar / masuk stok sedotan', Icons.history_outlined,
            () => open(const SedotanStockMovementPage()));

      // ── Laporan ──
      case MenuKey.tugasHarian:
        final names = dailyTaskMenu(ref.watch(menuAccessProvider)).map((k) => _dailyTaskShortNames[k]!);
        return card('Tugas Setiap Hari', _capitalize(names.join(', ')), Icons.checklist_rtl,
            () => open(const DailyTasksPage()));
      case MenuKey.shiftKasir:
        return card('Shift Kasir', 'Buka / tutup shift & rekap kas', Icons.point_of_sale_outlined,
            () => openOnDuty(const ShiftPage(), cashier: true));
      case MenuKey.laporanHarianLeader:
        return card('Laporan Harian Leader', 'Rekap per shift: penjualan, item, kas', Icons.leaderboard_outlined,
            () => open(const LeaderDailyReportPage()));
      case MenuKey.pengeluaran:
        return card('Pengeluaran', 'Catat biaya operasional', Icons.money_off_csred_outlined,
            () => open(const ExpenseListPage()));
      case MenuKey.riwayatPenjualan:
        return card('Riwayat Penjualan', 'Lihat transaksi penjualan hari ini', Icons.receipt_long_outlined,
            () => open(const TransactionHistoryListPage()));
      case MenuKey.yangBertugas:
        return card('Yang Bertugas', 'Siapa yang sudah absen masuk dan yang sedang izin keluar',
            Icons.groups_outlined, () => open(const OnDutyPage()));
      case MenuKey.penjualanOffline:
        return card('Penjualan Offline', 'Penjualan yang dibuat saat jaringan putus', Icons.cloud_off_outlined,
            () => open(const OfflineQueuePage()));
      case MenuKey.riwayatIzinKeluar:
        return card('Riwayat Izin Keluar', 'Riwayat keluar sebentar dari outlet', Icons.directions_walk,
            () => open(const LeaveOutListPage()));
      case MenuKey.laporanHarian:
        return card('Laporan Harian', 'Ringkasan transaksi per hari', Icons.calendar_today_outlined,
            () => open(const DailyReportPage()));
      case MenuKey.laporanPembayaran:
        return card('Laporan Pembayaran', 'Ringkasan pembayaran per metode', Icons.payments_outlined,
            () => open(const PaymentsReportPage()));

      // ── Tugas setiap hari ──
      case MenuKey.monitoringPesanan:
        final auth = ref.watch(authProvider);
        final canSwitch = canSwitchBranch(auth.held);
        return card(
          'Monitoring Pesanan',
          auth.branchId == null
              ? (canSwitch ? 'Pilih cabang aktif dulu' : 'Belum ada jadwal di outlet hari ini')
              : 'Layar dapur: pesanan masuk realtime',
          Icons.ramen_dining_outlined,
          () {
            // BE mengunci stream ke satu cabang. Owner yang belum memilih
            // cabang tidak punya branch_id, jadi diarahkan memilih dulu.
            if (auth.branchId == null) {
              if (canSwitch) {
                showBranchSwitchSheet(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(kNoOutletTodayMsg)));
              }
              return;
            }
            open(const KitchenDisplayPage());
          },
        );
      case MenuKey.ceklisFoto:
        return card('Ceklis Foto', 'Foto opening & closing shift', Icons.add_a_photo_outlined,
            () => openOnDuty(const PhotoChecklistPage()));
      case MenuKey.reminder:
        return card('Reminder', 'Catatan & permintaan foto dari SPV atau leader', Icons.campaign_outlined,
            () => open(const ReminderListPage()));
      case MenuKey.setoran:
        return card('Setoran', 'Bukti transfer setoran tunai outlet', Icons.account_balance_outlined,
            () => open(const CashDepositPage()));
      case MenuKey.bantuan:
        return card('Bantuan', 'Tiket ke SPV atau finance', Icons.support_agent,
            () => open(const HelpTicketListPage()));
      case MenuKey.arahanSpv:
        return card('Arahan SPV', 'Evaluasi harian, arahan, dan evaluasi bulanan', Icons.assignment_outlined,
            () => open(const DirectivesPage()));
      case MenuKey.sidak:
        return card('Sidak', 'Sidak outlet di lokasi', Icons.fact_check_outlined,
            () => open(const InspectionListPage()));

      // ── Profil ──
      case MenuKey.jatahMinum:
        final balance = ref.watch(myAllowanceProvider).when(
              data: (a) => formatRupiah(a.balance),
              loading: () => '…',
              error: (_, _) => '-',
            );
        return card('Jatah minum hari ini', 'Saldo, mutasi & pesanan jatah', Icons.local_cafe_outlined,
            () => open(const MyAllowancePage()),
            trailing: Text(balance,
                style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.brandBlue, fontSize: 16)));
      case MenuKey.skorKpi:
        final period = kpiPeriodOf(DateTime.now());
        final summary = ref.watch(myKpiProvider(period)).when(
              loading: () => 'Memuat…',
              error: (e, _) => e is KpiNotActive ? 'KPI belum berlaku bulan ini' : 'Gagal memuat skor',
              data: (v) => v.scores.isEmpty
                  ? 'Belum ada skor bulan ini'
                  : v.scores
                      .map((s) => '${kpiModuleLabels[s.module] ?? s.module} ${kpiNum(s.score)}'
                          '${s.predicate.isEmpty ? '' : ' · ${s.predicate}'}')
                      .join('   '),
            );
        return card('Skor KPI ${kpiPeriodLabel(period)}', summary, Icons.insights_outlined,
            () => open(const MyKpiPage()));
      case MenuKey.jadwalSaya:
        return card('Jadwal Saya', 'Shift, tugas & lokasi kerja', Icons.calendar_month_outlined,
            () => open(const MySchedulePage()));
      case MenuKey.absensi:
        return card('Absensi', 'Absen masuk & pulang pakai foto dan lokasi', Icons.fingerprint,
            () => open(const AttendancePage()));
      case MenuKey.izinKeluar:
        return const LeaveOutMenuCard();
      case MenuKey.slipGaji:
        return card('Slip Gaji', 'Rincian slip gaji tiap bulan, PDF, komplain', Icons.receipt_long_outlined,
            () => open(const PayslipListPage()));
      case MenuKey.pinjaman:
        return card('Pinjaman', 'Ajukan pinjaman dan lihat statusnya', Icons.request_quote_outlined,
            () => open(const MyLoansPage()));
      case MenuKey.pinjamanTunai:
        return card(
          'Pinjaman Tunai',
          switch (ref.watch(cashPendingLoansProvider).valueOrNull?.length) {
            null || 0 => 'Serahkan pinjaman karyawan dari laci',
            final n => '$n menunggu diserahkan dari laci',
          },
          Icons.payments_outlined,
          () => open(const CashLoanPage()),
        );
      case MenuKey.sop:
        return card('SOP', 'Standar kerja: foto & PDF dari owner', Icons.menu_book_outlined,
            () => open(const SopPage()));

      // ── Setting ──
      case MenuKey.perangkatCetak:
        return card('Perangkat Cetak', 'Printer default & cetak otomatis', Icons.print_outlined,
            () => open(const PrinterSettingsPage()));
      case MenuKey.produk:
        return card('Produk', 'Kelola daftar produk dan harga', Icons.local_cafe_outlined,
            () => open(const ProductListPage()));
      case MenuKey.gantiCabang:
        return card('Ganti Cabang', ref.watch(currentBranchProvider)?.name ?? 'Pilih cabang aktif',
            Icons.store_outlined, () => showBranchSwitchSheet(context));
      case MenuKey.qrisCabang:
        final auth = ref.watch(authProvider);
        final branch = ref.watch(currentBranchProvider);
        return card('QRIS Cabang', 'Mode pembayaran & QR statis cabang', Icons.qr_code_2,
            () => open(QrisSettingsPage(branchId: auth.branchId!, branchName: branch?.name)));
    }
  }
}
