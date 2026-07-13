import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/presentation/providers/shift_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

class ShiftListPage extends ConsumerWidget {
  const ShiftListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(shiftListProvider);
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Riwayat Shift')),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e', textAlign: TextAlign.center)),
        data: (shifts) {
          if (shifts.isEmpty) {
            return const Center(child: Text('Belum ada riwayat shift'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(shiftListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: shifts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final s = shifts[index];
                final isOpen = s.status == 'open';
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text('Shift #${s.id}', style: const TextStyle(fontWeight: FontWeight.w900)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isOpen ? AppTheme.brandBlue : AppTheme.textSecondary).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isOpen ? 'AKTIF' : 'SELESAI',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: isOpen ? AppTheme.brandBlue : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (s.openedAt != null)
                        Text('Buka: ${dateFmt.format(s.openedAt!.toLocal())}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      if (s.closedAt != null)
                        Text('Tutup: ${dateFmt.format(s.closedAt!.toLocal())}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const Divider(height: 18),
                      _row('Penjualan', formatRupiah(s.totalSales)),
                      if (s.totalExpense > 0) _row('Pengeluaran', '- ${formatRupiah(s.totalExpense)}'),
                      if (!isOpen) _row('Kas Seharusnya', formatRupiah(s.expectedCashResolved)),
                      if (!isOpen && s.closingCash != null)
                        _row('Kas Akhir', formatRupiah(s.closingCash!)),
                      if (!isOpen && s.differenceResolved != null)
                        _selisihRow(s.differenceResolved!),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _selisihRow(num diff) {
    final isMinus = diff < 0;
    final color = diff == 0
        ? AppTheme.textSecondary
        : (isMinus ? AppTheme.danger : AppTheme.brandBlue);
    final label = diff == 0 ? 'Sesuai' : (isMinus ? 'Kurang' : 'Lebih');
    return _row(
      'Selisih ($label)',
      '${isMinus ? '-' : ''}${formatRupiah(diff.abs())}',
      color: color,
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: color ?? AppTheme.textPrimary)),
        ],
      ),
    );
  }
}
