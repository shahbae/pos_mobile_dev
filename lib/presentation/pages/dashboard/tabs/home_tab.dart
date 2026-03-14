import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_mobile/presentation/pages/expenses/expense_list_page.dart';
import 'package:pos_mobile/presentation/pages/purchases/purchase_list_page.dart';
import 'package:pos_mobile/presentation/pages/transactions/transaction_history_page.dart';
import 'package:pos_mobile/presentation/providers/dashboard_operational_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _fmtRange(DateTimeRange range) {
    final fmt = DateFormat('dd MMM yyyy', 'id_ID');
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    if (start == end) return fmt.format(range.start);
    return "${fmt.format(range.start)} - ${fmt.format(range.end)}";
  }

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final current = ref.read(dashboardDateRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: current,
      helpText: 'Pilih Rentang Tanggal',
    );

    if (picked == null) return;
    ref.read(dashboardDateRangeProvider.notifier).state = picked;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(dashboardDateRangeProvider);
    final operationalAsync = ref.watch(dashboardOperationalProvider);
    final now = DateTime.now();
    final isToday = _isSameDay(range.start, now) && _isSameDay(range.end, now);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardOperationalProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _Header(
                rangeText: _fmtRange(range),
                onPickRange: () => _pickRange(context, ref),
              ),
              const SizedBox(height: 14),
              operationalAsync.when(
                data: (data) {
                  return Column(
                    children: [
                      _OperationalChartCard(
                        title: isToday ? "Grafik Hari Ini" : "Grafik Periode",
                        purchases: data.purchases.totalAmountNum,
                        expenses: data.expenses.totalAmountNum,
                        openBills: data.openBills.totalAmountNum,
                        net: data.netNum,
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              title: "Open Bills",
                              value: formatRupiah(
                                data.openBills.totalAmountNum,
                              ),
                              subtitle: "${data.openBills.count} tagihan",
                              icon: Icons.receipt_long_outlined,
                              iconColor: Colors.purple,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const TransactionHistoryListPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryCard(
                              title: "Net",
                              value: formatRupiah(data.netNum),
                              subtitle:
                                  "Sales ${data.sales.length} • Payments ${data.payments.length}",
                              icon: Icons.trending_up_outlined,
                              iconColor: AppTheme.brandBlue,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const TransactionHistoryListPage(),
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
    );
  }
}

class _OperationalChartCard extends StatelessWidget {
  final String title;
  final num purchases;
  final num expenses;
  final num openBills;
  final num net;

  const _OperationalChartCard({
    required this.title,
    required this.purchases,
    required this.expenses,
    required this.openBills,
    required this.net,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_ChartItem>[
      _ChartItem(label: "Pembelian", value: purchases, color: Colors.orange),
      _ChartItem(label: "Pengeluaran", value: expenses, color: Colors.red),
      _ChartItem(label: "Open Bills", value: openBills, color: Colors.purple),
      _ChartItem(
        label: "Net",
        value: net,
        color: net >= 0 ? AppTheme.brandBlue : AppTheme.danger,
      ),
    ];

    num maxAbs = 0;
    for (final it in items) {
      final v = it.value.abs();
      if (v > maxAbs) maxAbs = v;
    }
    if (maxAbs <= 0) maxAbs = 1;

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
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final it in items) ...[
                  Expanded(
                    child: _Bar(item: it, maxAbs: maxAbs),
                  ),
                  if (it != items.last) const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartItem {
  final String label;
  final num value;
  final Color color;

  const _ChartItem({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _Bar extends StatelessWidget {
  final _ChartItem item;
  final num maxAbs;

  const _Bar({required this.item, required this.maxAbs});

  @override
  Widget build(BuildContext context) {
    final ratio = (item.value.abs() / maxAbs).clamp(0, 1);
    final barHeight = 86 * ratio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              height: barHeight <= 0 ? 6 : barHeight.toDouble() + 6,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: item.color.withOpacity(0.28)),
              ),
              padding: const EdgeInsets.all(10),
              child: Align(
                alignment: Alignment.topLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: Text(
                    formatRupiah(item.value),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: item.color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String rangeText;
  final VoidCallback onPickRange;

  const _Header({required this.rangeText, required this.onPickRange});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
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
        ),
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPickRange,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppTheme.borderLight),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.date_range_outlined,
                  size: 18,
                  color: AppTheme.textPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  rangeText,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
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
