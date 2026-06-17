import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/presentation/pages/reports/daily_report_page.dart';
import 'package:pos_mobile/presentation/pages/reports/payments_report_page.dart';
import 'package:pos_mobile/presentation/pages/reports/stock_alerts_report_page.dart';
import 'package:pos_mobile/presentation/pages/transactions/transaction_history_page.dart';
import 'package:pos_mobile/theme/app_theme.dart';

class ReportTab extends ConsumerWidget {
  const ReportTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const accent = Color(0xFF22C55E);

    return ListView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset + 96),
      children: [
        // const _Header(),
        // const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withOpacity(0.20)),
          ),
          child: const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Kelola Bisnis Lebih Mudah",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Pantau laporan, pembayaran, dan riwayat transaksi dalam satu tempat.",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Icon(Icons.insights_outlined, color: accent, size: 28),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ReportMenuCard(
          title: "Laporan Harian",
          subtitle: "Ringkasan transaksi per hari",
          icon: Icons.calendar_today_outlined,
          color: accent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DailyReportPage()),
            );
          },
        ),
        const SizedBox(height: 16),
        _ReportMenuCard(
          title: "Stok Menipis",
          subtitle: "Daftar produk di bawah threshold",
          icon: Icons.warning_amber_rounded,
          color: accent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StockAlertsReportPage()),
            );
          },
        ),
        const SizedBox(height: 16),
        _ReportMenuCard(
          title: "Laporan Pembayaran",
          subtitle: "Ringkasan pembayaran per metode",
          icon: Icons.payments_outlined,
          color: accent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaymentsReportPage()),
            );
          },
        ),
        const SizedBox(height: 16),
        _ReportMenuCard(
          title: "Riwayat Penjualan",
          subtitle: "Lihat transaksi penjualan hari ini",
          icon: Icons.receipt_long_outlined,
          color: accent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TransactionHistoryListPage(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ReportMenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ReportMenuCard({
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
