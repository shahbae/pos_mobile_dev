import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_mobile/presentation/providers/daily_report_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

class PaymentsReportPage extends ConsumerWidget {
  const PaymentsReportPage({super.key});

  String _fmtRange(DateTimeRange range) {
    final fmt = DateFormat('dd MMM yyyy', 'id_ID');
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    if (start == end) return fmt.format(start);
    return "${fmt.format(start)} - ${fmt.format(end)}";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(paymentsReportRangeProvider);
    final reportAsync = ref.watch(paymentsReportProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text("Laporan Pembayaran"),
        backgroundColor: AppTheme.bgLight,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(paymentsReportProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
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
                          "Hari Ini",
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
                          onPressed: () => ref.invalidate(paymentsReportProvider),
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

                final totalPaid = data.rows.fold<num>(
                  0,
                  (sum, row) => sum + row.totalPaidNum,
                );
                final totalChange = data.rows.fold<num>(
                  0,
                  (sum, row) => sum + row.totalChangeNum,
                );

                return Column(
                  children: [
                    _SummaryCard(
                      totalPaid: totalPaid,
                      totalChange: totalChange,
                      totalCount: data.rows.fold<int>(0, (sum, row) => sum + row.count),
                    ),
                    const SizedBox(height: 12),
                    for (final row in data.rows) ...[
                      _PaymentRowCard(
                        method: row.paymentMethod,
                        status: row.paymentStatus,
                        count: row.count,
                        totalPaid: row.totalPaidNum,
                        totalChange: row.totalChangeNum,
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

class _SummaryCard extends StatelessWidget {
  final num totalPaid;
  final num totalChange;
  final int totalCount;

  const _SummaryCard({
    required this.totalPaid,
    required this.totalChange,
    required this.totalCount,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Ringkasan",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _SummaryRow(label: "Total pembayaran", value: formatRupiah(totalPaid)),
          const SizedBox(height: 6),
          _SummaryRow(label: "Total kembalian", value: formatRupiah(totalChange)),
          const SizedBox(height: 6),
          _SummaryRow(label: "Jumlah transaksi", value: "$totalCount"),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _PaymentRowCard extends StatelessWidget {
  final String method;
  final String status;
  final int count;
  final num totalPaid;
  final num totalChange;

  const _PaymentRowCard({
    required this.method,
    required this.status,
    required this.count,
    required this.totalPaid,
    required this.totalChange,
  });

  Color _statusColor(String status) {
    if (status.toLowerCase() == 'paid') return Colors.green;
    if (status.toLowerCase() == 'unpaid') return Colors.orange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(status);
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.payments_outlined, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  method.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${status.toUpperCase()} • $count transaksi",
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
              Text(
                formatRupiah(totalPaid),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Kembalian ${formatRupiah(totalChange)}",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

