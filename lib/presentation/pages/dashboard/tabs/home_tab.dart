import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_mobile/data/models/dashboard_model.dart';
import 'package:pos_mobile/data/models/dashboard_operational_model.dart';
import 'package:pos_mobile/presentation/pages/expenses/expense_list_page.dart';
import 'package:pos_mobile/presentation/pages/purchases/purchase_list_page.dart';
import 'package:pos_mobile/presentation/providers/branch_provider.dart';
import 'package:pos_mobile/presentation/providers/dashboard_operational_provider.dart';
import 'package:pos_mobile/presentation/widgets/branch_switch_sheet.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dashboard adaptif per-role (GET /dashboard, revisi BE 2026-06-29).
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardProvider);
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const _Header(),
                  const SizedBox(height: 14),
                  dashboardAsync.when(
                    data: (data) => _DashboardSections(data: data),
                    loading: () => const _DashboardSkeleton(),
                    error: (e, _) => Column(
                      children: [
                        const SizedBox(height: 24),
                        _ErrorCard(
                          message: e.toString(),
                          onRetry: () => ref.invalidate(dashboardProvider),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Merangkai section dashboard sesuai data yang dikirim BE untuk role aktif.
class _DashboardSections extends StatelessWidget {
  final DashboardData data;
  const _DashboardSections({required this.data});

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[];
    final op = data.operational;

    if (op != null) {
      sections.add(_RevenueChartCard(
        title: "Grafik Hari Ini",
        chart: op.chart,
        primaryTransactionType: op.primaryTransactionType,
      ));
      sections.add(const SizedBox(height: 12));
      sections.add(Row(
        children: [
          Expanded(
            child: _SummaryCard(
              title: "Penjualan",
              value: formatRupiah(op.primarySales.totalAmountNum),
              subtitle: "${op.primarySales.count} transaksi",
              icon: Icons.point_of_sale_outlined,
              iconColor: AppTheme.brandBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              title: "Bersih",
              value: formatRupiah(op.netNum),
              subtitle: "Penjualan - beli - keluar",
              icon: Icons.account_balance_wallet_outlined,
              iconColor: Colors.teal,
            ),
          ),
        ],
      ));
      sections.add(const SizedBox(height: 12));
      sections.add(Row(
        children: [
          Expanded(
            child: _SummaryCard(
              title: "Pembelian",
              value: formatRupiah(op.purchases.totalAmountNum),
              subtitle: "${op.purchases.count} transaksi",
              icon: Icons.shopping_cart_checkout_outlined,
              iconColor: Colors.orange,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PurchaseListPage())),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              title: "Pengeluaran",
              value: formatRupiah(op.expenses.totalAmountNum),
              subtitle: "${op.expenses.count} transaksi",
              icon: Icons.money_off_csred_outlined,
              iconColor: Colors.red,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ExpenseListPage())),
            ),
          ),
        ],
      ));
    }

    if (data.currentShift != null) {
      sections.add(const SizedBox(height: 12));
      sections.add(_ShiftCard(shift: data.currentShift!));
    }

    if (data.profit != null) {
      sections.add(const SizedBox(height: 12));
      sections.add(_ProfitCard(profit: data.profit!));
    }

    if (data.payments.isNotEmpty) {
      sections.add(const SizedBox(height: 12));
      sections.add(_PaymentsCard(rows: data.payments));
    }

    if (data.topProducts.isNotEmpty) {
      sections.add(const SizedBox(height: 12));
      sections.add(_TopProductsCard(rows: data.topProducts));
    }

    if (data.perBranch.isNotEmpty) {
      sections.add(const SizedBox(height: 12));
      sections.add(_PerBranchCard(rows: data.perBranch));
    }

    if (data.teamAttendance.isNotEmpty) {
      sections.add(const SizedBox(height: 12));
      sections.add(_TeamAttendanceCard(rows: data.teamAttendance));
    }

    if (data.attendanceToday != null) {
      sections.add(const SizedBox(height: 12));
      sections.add(_AttendanceTodayCard(day: data.attendanceToday!));
    }

    if (data.attendanceHistory.isNotEmpty) {
      sections.add(const SizedBox(height: 12));
      sections.add(_AttendanceHistoryCard(rows: data.attendanceHistory));
    }

    if (data.recentTransactions.isNotEmpty) {
      sections.add(const SizedBox(height: 12));
      sections.add(_RecentTransactionsCard(rows: data.recentTransactions));
    }

    if (sections.isEmpty) {
      sections.add(const _EmptyDashboard());
    }

    return Column(children: sections);
  }
}

class _RevenueChartCard extends StatelessWidget {
  final String title;
  final DashboardOperationalChart? chart;
  final String? primaryTransactionType;

  const _RevenueChartCard({
    required this.title,
    required this.chart,
    required this.primaryTransactionType,
  });

  @override
  Widget build(BuildContext context) {
    final points = chart?.points ?? const <DashboardOperationalChartPoint>[];
    if (points.isEmpty) return const SizedBox.shrink();

    final primaryValues = points.map((e) => e.primaryRevenueNum).toList();
    final totalValues = points.map((e) => e.revenueTotalNum).toList();

    bool hasPrimary = false;
    for (final v in primaryValues) {
      if (v != 0) {
        hasPrimary = true;
        break;
      }
    }

    final values = hasPrimary ? primaryValues : totalValues;
    num maxValue = 0;
    num sumValue = 0;
    for (final v in values) {
      if (v > maxValue) maxValue = v;
      sumValue += v;
    }
    if (maxValue <= 0) maxValue = 1;

    final intervalText = (chart?.interval ?? '').toString();
    final primaryText = (primaryTransactionType ?? '').isEmpty
        ? null
        : primaryTransactionType!.toUpperCase();
    final subtitle = <String>[
      if (intervalText.isNotEmpty) intervalText,
      if (primaryText != null) "Primary $primaryText",
    ].join(" • ");

    final timeFmt = DateFormat('HH:mm', 'id_ID');
    final startLabel = timeFmt.format(points.first.time.toLocal());
    final midLabel = timeFmt.format(points[points.length ~/ 2].time.toLocal());
    final endLabel = timeFmt.format(points.last.time.toLocal());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                formatRupiah(sumValue),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            width: double.infinity,
            child: CustomPaint(
              painter: _RevenueLineChartPainter(
                values: values,
                maxValue: maxValue,
                color: AppTheme.brandBlue,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                startLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                midLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                endLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RevenueLineChartPainter extends CustomPainter {
  final List<num> values;
  final num maxValue;
  final Color color;

  const _RevenueLineChartPainter({
    required this.values,
    required this.maxValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.16)
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final count = values.length;
    if (count < 2) return;

    final left = 2.0;
    final top = 6.0;
    final right = size.width - 2.0;
    final bottom = size.height - 8.0;
    final w = (right - left).clamp(0, double.infinity);
    final h = (bottom - top).clamp(0, double.infinity);

    for (var i = 0; i < 4; i++) {
      final y = top + (h / 3) * i;
      bgPaint.color = AppTheme.borderLight.withOpacity(0.7);
      canvas.drawLine(Offset(left, y), Offset(right, y), bgPaint);
    }

    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < count; i++) {
      final x = left + (w * i / (count - 1));
      final v = values[i];
      final ratio = (v / maxValue).clamp(0, 1);
      final y = top + (h * (1 - ratio));
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, bottom);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(right, bottom);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final lastX = left + w;
    final lastRatio = (values.last / maxValue).clamp(0, 1);
    final lastY = top + (h * (1 - lastRatio));
    canvas.drawCircle(Offset(lastX, lastY), 3.4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _RevenueLineChartPainter oldDelegate) {
    if (oldDelegate.maxValue != maxValue) return true;
    if (oldDelegate.color != color) return true;
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentBranch = ref.watch(currentBranchProvider);
    final accent = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Beranda",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Ringkasan operasional",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => showBranchSwitchSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: currentBranch != null
                  ? accent.withOpacity(0.08)
                  : Colors.white,
              border: Border.all(
                color: currentBranch != null
                    ? accent.withOpacity(0.35)
                    : AppTheme.borderLight,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.store_outlined,
                  size: 15,
                  color: currentBranch != null ? accent : AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  currentBranch?.name ?? 'Pilih Cabang',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: currentBranch != null ? accent : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: currentBranch != null ? accent : AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: AppTheme.danger),
              SizedBox(width: 8),
              Text(
                "Gagal memuat dashboard",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Coba Lagi"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderLight),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderLight),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderLight),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderLight),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Section cards (dashboard adaptif) ──────────────

/// Kontainer kartu section dengan judul + opsi widget kanan + isi.
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.brandBlue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: AppTheme.brandBlue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Daftar baris dengan pemisah tipis antar item.
Widget _separated(List<Widget> rows) {
  final out = <Widget>[];
  for (var i = 0; i < rows.length; i++) {
    out.add(rows[i]);
    if (i != rows.length - 1) {
      out.add(Divider(height: 1, color: AppTheme.borderLight.withOpacity(0.7)));
    }
  }
  return Column(children: out);
}

/// Baris label-nilai standar (label kiri abu, nilai kanan tebal).
Widget _lineRow(
  String label,
  String value, {
  bool strong = false,
  Color? valueColor,
  Widget? leading,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        if (leading != null) ...[leading, const SizedBox(width: 10)],
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    ),
  );
}

/// Blok angka besar berlatar tinted (untuk metrik penting).
Widget _metricTile(String label, String value, Color color) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _statusChip(String text, {required bool positive}) {
  final c = positive ? const Color(0xFF16A34A) : AppTheme.textSecondary;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c),
    ),
  );
}

String _shiftStatusLabel(String s) {
  switch (s.toLowerCase()) {
    case 'open':
      return 'Terbuka';
    case 'closed':
      return 'Ditutup';
    default:
      return s.isEmpty ? '-' : s;
  }
}

class _ShiftCard extends StatelessWidget {
  final DashboardShift shift;
  const _ShiftCard({required this.shift});

  @override
  Widget build(BuildContext context) {
    final isOpen = shift.status.toLowerCase() == 'open';
    return _SectionCard(
      title: 'Shift Berjalan',
      icon: Icons.point_of_sale_outlined,
      trailing: _statusChip(_shiftStatusLabel(shift.status), positive: isOpen),
      children: [
        Row(
          children: [
            _metricTile('Total Penjualan', formatRupiah(shift.totalSales),
                AppTheme.brandBlue),
            const SizedBox(width: 10),
            _metricTile('Kas Seharusnya', formatRupiah(shift.expectedCash),
                Colors.teal),
          ],
        ),
        const SizedBox(height: 6),
        _separated([
          _lineRow('Kasir', shift.cashierName),
          _lineRow('Modal Awal', formatRupiah(shift.openingCash)),
          if (shift.payments.isNotEmpty)
            ...shift.payments.map(
              (p) => _lineRow(p.method.toUpperCase(), formatRupiah(p.total)),
            ),
        ]),
      ],
    );
  }
}

class _ProfitCard extends StatelessWidget {
  final DashboardProfit profit;
  const _ProfitCard({required this.profit});

  @override
  Widget build(BuildContext context) {
    final positive = profit.netProfit >= 0;
    return _SectionCard(
      title: 'Laba Rugi',
      icon: Icons.trending_up,
      children: [
        _metricTile(
          'Laba Bersih',
          formatRupiah(profit.netProfit),
          positive ? const Color(0xFF16A34A) : AppTheme.danger,
        ),
        const SizedBox(height: 6),
        _separated([
          _lineRow('Pendapatan', formatRupiah(profit.revenue)),
          _lineRow('HPP (COGS)', formatRupiah(profit.cogs)),
          _lineRow('Laba Kotor', formatRupiah(profit.grossProfit)),
          _lineRow('Pengeluaran', formatRupiah(profit.expenses)),
        ]),
      ],
    );
  }
}

class _PaymentsCard extends StatelessWidget {
  final List<DashboardPaymentRow> rows;
  const _PaymentsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Pembayaran',
      icon: Icons.payments_outlined,
      children: [
        _separated(rows
            .map((r) => _lineRow(
                  r.count > 0
                      ? '${r.method.toUpperCase()} · ${r.count}x'
                      : r.method.toUpperCase(),
                  formatRupiah(r.total),
                ))
            .toList()),
      ],
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  final List<DashboardTopProduct> rows;
  const _TopProductsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Produk Terlaris',
      icon: Icons.star_outline,
      children: [
        _separated([
          for (var i = 0; i < rows.length; i++)
            _lineRow(
              rows[i].qty > 0 ? '${rows[i].name} · ${rows[i].qty}x' : rows[i].name,
              formatRupiah(rows[i].total),
              leading: _rankBadge(i + 1),
            ),
        ]),
      ],
    );
  }
}

Widget _rankBadge(int n) {
  return Container(
    width: 22,
    height: 22,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppTheme.brandBlue.withOpacity(0.12),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      '$n',
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: AppTheme.brandBlue,
      ),
    ),
  );
}

class _PerBranchCard extends StatelessWidget {
  final List<DashboardBranchRow> rows;
  const _PerBranchCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Per Cabang',
      icon: Icons.store_mall_directory_outlined,
      children: [
        _separated(rows
            .map((r) => _lineRow(
                  r.transactions > 0 ? '${r.name} · ${r.transactions} trx' : r.name,
                  formatRupiah(r.sales),
                ))
            .toList()),
      ],
    );
  }
}

class _TeamAttendanceCard extends StatelessWidget {
  final List<DashboardAttendanceRow> rows;
  const _TeamAttendanceCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Absensi Tim',
      icon: Icons.groups_outlined,
      children: [
        _separated(rows
            .map((r) => _lineRow(r.name, r.status.isEmpty ? '-' : r.status))
            .toList()),
      ],
    );
  }
}

String _hm(DateTime? dt) {
  if (dt == null) return '-';
  final l = dt.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

String _dmy(DateTime? dt) {
  if (dt == null) return '-';
  final l = dt.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
}

class _AttendanceTodayCard extends StatelessWidget {
  final DashboardAttendanceDay day;
  const _AttendanceTodayCard({required this.day});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Absensi Hari Ini',
      icon: Icons.fingerprint,
      trailing: _statusChip(
        !day.hasCheckedIn
            ? 'Belum absen'
            : (day.hasCheckedOut ? 'Sudah pulang' : 'Sedang bekerja'),
        positive: day.hasCheckedIn,
      ),
      children: [
        if (!day.hasCheckedIn)
          _lineRow('Status', 'Belum absen masuk')
        else
          _separated([
            _lineRow('Absen Masuk', _hm(day.checkInAt)),
            _lineRow('Absen Pulang', day.hasCheckedOut ? _hm(day.checkOutAt) : 'Belum'),
            if (day.shift.isNotEmpty) _lineRow('Shift', day.shift),
          ]),
      ],
    );
  }
}

class _AttendanceHistoryCard extends StatelessWidget {
  final List<DashboardAttendanceDay> rows;
  const _AttendanceHistoryCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Riwayat Absensi',
      icon: Icons.history,
      children: [
        _separated(rows
            .map((r) => _lineRow(
                  _dmy(r.date),
                  '${_hm(r.checkInAt)} - ${r.hasCheckedOut ? _hm(r.checkOutAt) : '...'}',
                ))
            .toList()),
      ],
    );
  }
}

class _RecentTransactionsCard extends StatelessWidget {
  final List<DashboardRecentTx> rows;
  const _RecentTransactionsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Transaksi Terakhir',
      icon: Icons.receipt_long_outlined,
      children: [
        _separated(rows.map(_txTile).toList()),
      ],
    );
  }

  Widget _txTile(DashboardRecentTx r) {
    final title = r.customerName != null && r.customerName!.isNotEmpty
        ? r.customerName!
        : r.invoiceNo;
    final sub = <String>[
      if (r.customerName != null && r.customerName!.isNotEmpty) r.invoiceNo,
      if (r.createdAt != null) _hm(r.createdAt),
      if (r.paymentMethod.isNotEmpty) r.paymentMethod.toUpperCase(),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.brandBlue.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_outlined,
                size: 17, color: AppTheme.brandBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatRupiah(r.total),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: const Column(
        children: [
          Icon(Icons.dashboard_outlined, size: 36, color: AppTheme.textSecondary),
          SizedBox(height: 10),
          Text(
            'Belum ada data untuk ditampilkan',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
