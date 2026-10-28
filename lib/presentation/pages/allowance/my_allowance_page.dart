import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/allowance_model.dart';
import 'package:pos_mobile/presentation/providers/allowance_provider.dart';
import 'package:pos_mobile/presentation/widgets/paged_list_view.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

final _time = DateFormat('HH.mm', 'id_ID');
final _dateTime = DateFormat('d MMM yyyy, HH.mm', 'id_ID');

/// Kartu saldo jatah hari ini di Profil; ketuk untuk rinciannya.
class MyAllowanceCard extends ConsumerWidget {
  const MyAllowanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myAllowanceProvider);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyAllowancePage())),
      child: SdmCard(
        child: Row(
          children: [
            const Icon(Icons.local_cafe_outlined, color: AppTheme.brandBlue),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Jatah minum hari ini', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            Text(
              async.when(
                data: (a) => formatRupiah(a.balance),
                loading: () => '…',
                error: (_, __) => '-',
              ),
              style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.brandBlue, fontSize: 16),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Saldo jatah hari ini, mutasinya, dan pesanan jatah yang pernah diterima.
class MyAllowancePage extends ConsumerWidget {
  const MyAllowancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(myAllowanceProvider);
    final orders = ref.watch(myAllowanceOrdersProvider);
    final notifier = ref.read(myAllowanceOrdersProvider.notifier);
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Jatah Saya'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: today.when(
              loading: () => const SdmCard(child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SdmCard(
                child: Row(
                  children: [
                    Expanded(child: Text('$e')),
                    TextButton(
                      onPressed: () => ref.invalidate(myAllowanceProvider),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
              data: (a) => _Today(a),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Pesanan jatah yang kamu terima',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
          Expanded(
            child: PagedListView<AllowanceOrder>(
              state: orders,
              notifier: notifier,
              unit: 'pesanan',
              emptyText: 'Belum pernah menerima pesanan jatah.',
              itemBuilder: (context, o) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _OrderTile(o),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Today extends StatelessWidget {
  final MyAllowance a;
  const _Today(this.a);

  @override
  Widget build(BuildContext context) {
    return SdmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sisa jatah hari ini', style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(formatRupiah(a.balance),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.brandBlue)),
          const SizedBox(height: 4),
          const Text('Didapat dari absen masuk dan lembur. Hangus tiap 00.00.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          if (a.entries.isNotEmpty) ...[
            const Divider(height: 24, color: AppTheme.borderLight),
            for (final e in a.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(e.createdAt == null ? '' : _time.format(e.createdAt!),
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ),
                    Expanded(
                      child: Text(e.invoiceNo == null ? e.label : '${e.label} · ${e.invoiceNo}',
                          style: const TextStyle(fontSize: 13)),
                    ),
                    Text(
                      '${e.amount > 0 ? '+' : '−'}${formatRupiah(e.amount.abs())}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: e.amount > 0 ? Colors.green.shade700 : AppTheme.danger,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final AllowanceOrder o;
  const _OrderTile(this.o);

  @override
  Widget build(BuildContext context) {
    return SdmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(o.invoiceNo, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              Text(formatRupiah(o.total), style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              if (o.createdAt != null) _dateTime.format(o.createdAt!),
              if (o.branchName.isNotEmpty) o.branchName,
              if (o.cashierName.isNotEmpty) 'oleh ${o.cashierName}',
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          for (final i in o.items)
            Text(
              '${i.qty}× ${i.displayName}${i.toppings.isEmpty ? '' : ' + ${i.toppings.join(', ')}'}',
              style: const TextStyle(fontSize: 13),
            ),
        ],
      ),
    );
  }
}
