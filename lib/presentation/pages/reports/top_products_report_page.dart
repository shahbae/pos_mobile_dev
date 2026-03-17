import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_mobile/presentation/providers/daily_report_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

class TopProductsReportPage extends ConsumerWidget {
  const TopProductsReportPage({super.key});

  String _fmtRange(DateTimeRange range) {
    final fmt = DateFormat('dd MMM yyyy', 'id_ID');
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    if (start == end) return fmt.format(start);
    return "${fmt.format(start)} - ${fmt.format(end)}";
  }

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final current = ref.read(topProductsRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: current,
      helpText: 'Pilih Rentang Tanggal',
    );

    if (picked == null) return;
    ref.read(topProductsRangeProvider.notifier).state = DateTimeRange(
      start: DateTime(picked.start.year, picked.start.month, picked.start.day),
      end: DateTime(picked.end.year, picked.end.month, picked.end.day),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(topProductsRangeProvider);
    final limit = ref.watch(topProductsLimitProvider);
    final reportAsync = ref.watch(topProductsReportProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text("Top Products"),
        backgroundColor: AppTheme.bgLight,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(topProductsReportProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _pickRange(context, ref),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.brandBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.date_range_outlined,
                        color: AppTheme.brandBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Periode",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _fmtRange(range),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.format_list_numbered_outlined,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Limit",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  DropdownButton<int>(
                    value: limit,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 5, child: Text("5")),
                      DropdownMenuItem(value: 10, child: Text("10")),
                      DropdownMenuItem(value: 20, child: Text("20")),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      ref.read(topProductsLimitProvider.notifier).state = v;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            reportAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Gagal memuat laporan",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => ref.invalidate(topProductsReportProvider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandBlue,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("Coba Lagi"),
                        ),
                      ),
                    ],
                  ),
                );
              },
              data: (data) {
                if (data.rows.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: const Text(
                      "Tidak ada data",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (int i = 0; i < data.rows.length; i++) ...[
                      _TopProductCard(
                        rank: i + 1,
                        name: data.rows[i].name,
                        sku: data.rows[i].sku,
                        qtySold: data.rows[i].qtySold,
                        revenue: data.rows[i].revenueNum,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TopProductCard extends StatelessWidget {
  final int rank;
  final String name;
  final String? sku;
  final int qtySold;
  final num revenue;

  const _TopProductCard({
    required this.rank,
    required this.name,
    required this.sku,
    required this.qtySold,
    required this.revenue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.brandBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "#$rank",
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppTheme.brandBlue,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sku == null || sku!.isEmpty ? "SKU: -" : "SKU: $sku",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Qty terjual: $qtySold",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                "Revenue",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatRupiah(revenue),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

