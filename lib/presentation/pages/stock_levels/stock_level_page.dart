import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/material_model.dart';
import 'package:pos_mobile/data/models/stock_level_model.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/material_provider.dart';
import 'package:pos_mobile/presentation/providers/stock_level_provider.dart';
import 'package:pos_mobile/presentation/widgets/stock_packs_view.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Stok material: lihat saldo per material + penyesuaian (adjust) stok.
/// Qty material kini DESIMAL; nama/unit + kemasan (packs) datang dari response.
class StockLevelPage extends ConsumerWidget {
  const StockLevelPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelsAsync = ref.watch(materialStockLevelsProvider);
    final materialsAsync = ref.watch(materialListProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Stok Material'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(materialStockLevelsProvider),
        child: levelsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            Center(child: Text('Gagal memuat stok:\n$e', textAlign: TextAlign.center)),
          ]),
          data: (levels) {
            // Fallback nama/unit bila response lama belum meng-enrich name/unit.
            final names = <int, MaterialItem>{};
            materialsAsync.whenData((mats) {
              for (final m in mats) {
                names[m.id] = m;
              }
            });

            if (levels.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 140),
                Icon(Icons.inventory_outlined, size: 56, color: AppTheme.textSecondary),
                SizedBox(height: 12),
                Center(child: Text('Belum ada data stok', style: TextStyle(color: AppTheme.textSecondary))),
              ]);
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: levels.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final lv = levels[i];
                final mat = lv.materialId != null ? names[lv.materialId] : null;
                final name = lv.name.isNotEmpty
                    ? lv.name
                    : (mat?.name ?? 'Material #${lv.materialId}');
                final unit = lv.unit.isNotEmpty ? lv.unit : (mat?.unit ?? '');
                return _StockRow(
                  level: lv,
                  name: name,
                  unit: unit,
                  onAdjust: canAdjustStock(ref.watch(authProvider).role)
                      ? () => _showAdjustDialog(context, ref, lv, name, unit)
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _showAdjustDialog(
    BuildContext context,
    WidgetRef ref,
    StockLevelModel lv,
    String name,
    String unit,
  ) async {
    final controller = TextEditingController(text: _fmtQty(lv.qtyOnHand));
    final result = await showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sesuaikan Stok — $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stok sistem saat ini: ${_fmtQty(lv.qtyOnHand)} $unit'.trim(),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                labelText: 'Stok fisik (baru)',
                suffixText: unit,
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
              // kirim int bila bulat, double bila desimal
              Navigator.pop(ctx, v == v.roundToDouble() ? v.toInt() : v);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result == null || lv.materialId == null) return;

    try {
      await ref.read(stockLevelRepositoryProvider).adjustStock(
            materialId: lv.materialId!,
            newQty: result,
          );
      ref.invalidate(materialStockLevelsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Stok berhasil disesuaikan'),
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

  /// Tampilkan tanpa .0 bila bulat (2400.0 → "2400", 2400.5 → "2400.5").
  static String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}

class _StockRow extends StatelessWidget {
  final StockLevelModel level;
  final String name;
  final String unit;
  final VoidCallback? onAdjust;

  const _StockRow({
    required this.level,
    required this.name,
    required this.unit,
    required this.onAdjust,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  '${StockLevelPage._fmtQty(level.qtyOnHand)} $unit'.trim(),
                  style: const TextStyle(fontSize: 14, color: AppTheme.brandBlue, fontWeight: FontWeight.w700),
                ),
                StockPacksView(packs: level.packs, unit: unit),
                if (level.incomingToday > 0) ...[
                  const SizedBox(height: 2),
                  Text('Masuk hari ini: ${StockLevelPage._fmtQty(level.incomingToday)} $unit'.trim(),
                      style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w700)),
                ],
                if (level.updatedAt != null) ...[
                  const SizedBox(height: 2),
                  Text('Update: ${_fmt(level.updatedAt!)}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ],
            ),
          ),
          if (onAdjust != null)
            OutlinedButton.icon(
              onPressed: onAdjust,
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

  String _fmt(String iso) {
    try {
      return DateFormat('dd MMM yyyy • HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }
}
