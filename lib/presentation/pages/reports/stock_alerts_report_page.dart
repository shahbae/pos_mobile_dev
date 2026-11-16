import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_mobile/presentation/providers/daily_report_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

class StockAlertsReportPage extends ConsumerWidget {
  const StockAlertsReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(stockAlertsReportProvider);
    final fmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text("Stok Menipis"),
        backgroundColor: AppTheme.bgLight,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(stockAlertsReportProvider);
        },
        child: reportAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) {
            return ListView(
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
                          onPressed: () => ref.invalidate(stockAlertsReportProvider),
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
                ),
              ],
            );
          },
          data: (data) {
            if (data.rows.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _HeaderCard(total: 0),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Tidak ada barang yang stoknya menipis",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Layar ini juga kosong bila batas stok belum diisi. "
                          "Barang tanpa batas tidak pernah diperingatkan; "
                          "owner atau SPV mengisi batasnya di web admin "
                          "(menu Atur Batas Stok).",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _HeaderCard(total: data.rows.length),
                const SizedBox(height: 12),
                for (final row in data.rows) ...[
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
                            color: AppTheme.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: AppTheme.danger,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                row.branchName.isEmpty
                                    ? row.typeLabel
                                    : "${row.typeLabel} · ${row.branchName}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Batas ${row.thresholdText} · ${row.baseText}"
                                "${row.updatedAt == null ? '' : ' · ${fmt.format(row.updatedAt!.toLocal())}'}",
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
                        // Angka kemasan lebih panjang dari angka dulu ("1,4 Jerigen"):
                        // dibatasi lebarnya dan boleh turun baris, supaya di HP 360 dp
                        // tidak meluap.
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 104),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.danger.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              "Stok: ${row.stockText}",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppTheme.danger,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final int total;

  const _HeaderCard({required this.total});

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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.brandBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: AppTheme.brandBlue),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Batas stok",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Per barang, dalam kemasan",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.brandBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              "$total item",
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppTheme.brandBlue,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
