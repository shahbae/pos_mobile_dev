import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/sedotan_stock_model.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/sedotan_provider.dart';
import 'package:pos_mobile/presentation/widgets/stock_packs_view.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Stok sedotan: lihat saldo per sedotan + penyesuaian (adjust) stok. Qty desimal.
class SedotanStockPage extends ConsumerWidget {
  const SedotanStockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockAsync = ref.watch(sedotanStockListProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Stok Sedotan'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(sedotanStockListProvider),
        child: stockAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            Center(child: Text('Gagal memuat stok sedotan:\n$e', textAlign: TextAlign.center)),
          ]),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 140),
                Icon(Icons.local_drink_outlined, size: 56, color: AppTheme.textSecondary),
                SizedBox(height: 12),
                Center(child: Text('Belum ada data stok sedotan', style: TextStyle(color: AppTheme.textSecondary))),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _row(
                context,
                ref,
                list[i],
                canAdjustStock(ref.watch(authProvider).role),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, SedotanStock s, bool canAdjust) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  '${_fmtQty(s.qty)} ${s.unit}'.trim(),
                  style: TextStyle(
                      fontSize: 14,
                      color: s.qty < 0 ? AppTheme.danger : AppTheme.brandBlue,
                      fontWeight: FontWeight.w700),
                ),
                StockPacksView(packs: s.packs, unit: s.unit),
                if (s.incomingToday > 0) ...[
                  const SizedBox(height: 2),
                  Text('Masuk hari ini: ${_fmtQty(s.incomingToday)} ${s.unit}'.trim(),
                      style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          if (canAdjust)
            OutlinedButton.icon(
              onPressed: () => _showAdjustDialog(context, ref, s),
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('Sesuaikan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.brandBlue,
                side: const BorderSide(color: AppTheme.brandBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAdjustDialog(BuildContext context, WidgetRef ref, SedotanStock s) async {
    final controller = TextEditingController(text: _fmtQty(s.qty));
    final result = await showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sesuaikan Stok — ${s.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stok sistem saat ini: ${_fmtQty(s.qty)} ${s.unit}'.trim(),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                labelText: 'Stok fisik (baru)',
                suffixText: s.unit,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              if (v == null) return;
              Navigator.pop(ctx, v == v.roundToDouble() ? v.toInt() : v);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      await ref.read(sedotanRepositoryProvider).adjustSedotanStock(
            sedotanId: s.sedotanId,
            newQty: result,
          );
      ref.invalidate(sedotanStockListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Stok sedotan berhasil disesuaikan'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  /// Tampilkan tanpa .0 bila bulat (82.0 → "82", 82.5 → "82.5").
  String _fmtQty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}
