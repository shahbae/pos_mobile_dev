import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/payroll_model.dart';
import 'package:pos_mobile/presentation/pages/payroll/payroll_widgets.dart';
import 'package:pos_mobile/presentation/pages/payroll/payslip_detail_page.dart';
import 'package:pos_mobile/presentation/providers/payroll_provider.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

/// Slip gaji sendiri (Tahap 2 SDM). Slip terbit sesudah owner menyetujui
/// penggajian bulan itu; sebelum itu tidak tampil sama sekali.
class PayslipListPage extends ConsumerWidget {
  const PayslipListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myPayslipsProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Slip Gaji'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myPayslipsProvider),
        child: async.when(
          loading: SdmStateView.loading,
          error: (e, _) => SdmStateView(
            icon: Icons.error_outline,
            message: '$e',
            onRetry: () => ref.invalidate(myPayslipsProvider),
          ),
          data: (rows) => ListView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
            children: [
              const SdmNote(
                icon: Icons.info_outline,
                text: 'Gajian tiap tanggal 27. Slip muncul di sini sesudah owner '
                    'menyetujui penggajian bulan itu.',
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                const SdmEmpty(icon: Icons.receipt_long_outlined, message: 'Belum ada slip gaji.'),
              for (final r in rows) ...[
                _PayslipCard(row: r),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PayslipCard extends StatelessWidget {
  final MyPayslipRow row;
  const _PayslipCard({required this.row});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PayslipDetailPage(payslipId: row.id)),
      ),
      child: SdmCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Gaji ${paydayMonth(row.payday)}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
              ],
            ),
            const SizedBox(height: 2),
            Text('Absensi ${periodRange(row.periodFrom, row.periodTo)}',
                style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
            const SizedBox(height: 10),
            Text(formatRupiah(row.netPay),
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.brandGreenDark)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                row.transferredAt == null
                    ? const SdmPill('Belum ditransfer', color: Color(0xFFD97706))
                    : SdmPill('Ditransfer ${payrollDate(row.transferredAt)}', color: AppTheme.brandGreenDark),
                if (row.openComplaint) const SdmPill('Komplain menunggu', color: Color(0xFF2563EB)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
