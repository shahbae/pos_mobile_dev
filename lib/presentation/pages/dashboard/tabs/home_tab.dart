import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
    final operationalAsync = ref.watch(dashboardOperationalProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardOperationalProvider);
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
              operationalAsync.when(
                data: (data) {
                  return Column(
                    children: [
                      _RevenueChartCard(
                        title: "Grafik Hari Ini",
                        chart: data.chart,
                        primaryTransactionType: data.primaryTransactionType,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              title: "Pembelian",
                              value: formatRupiah(
                                data.purchases.totalAmountNum,
                              ),
                              subtitle: "${data.purchases.count} transaksi",
                              icon: Icons.shopping_cart_checkout_outlined,
                              iconColor: Colors.orange,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PurchaseListPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryCard(
                              title: "Pengeluaran",
                              value: formatRupiah(data.expenses.totalAmountNum),
                              subtitle: "${data.expenses.count} transaksi",
                              icon: Icons.money_off_csred_outlined,
                              iconColor: Colors.red,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ExpenseListPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
                loading: () => const _DashboardSkeleton(),
                error: (e, _) {
                  return Column(
                    children: [
                      const SizedBox(height: 24),
                      _ErrorCard(
                        message: e.toString(),
                        onRetry: () =>
                            ref.invalidate(dashboardOperationalProvider),
                      ),
                    ],
                  );
                },
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
