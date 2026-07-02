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
import 'package:pos_mobile/theme/app_theme.dart';

/// Stok material: lihat saldo per material + penyesuaian (adjust) stok.
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
            // Peta material_id -> nama (dari daftar material).
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
                return _StockRow(
                  level: lv,
                  material: mat,
                  onAdjust: canAdjustStock(ref.watch(authProvider).role)
                      ? () => _showAdjustDialog(context, ref, lv, mat)
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
    MaterialItem? mat,
  ) async {
    final controller = TextEditingController(text: '${lv.qtyOnHand ?? 0}');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sesuaikan Stok — ${mat?.name ?? 'Material #${lv.materialId}'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stok sistem saat ini: ${lv.qtyOnHand ?? 0}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Stok fisik (baru)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              if (v != null) Navigator.pop(ctx, v);
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
}

class _StockRow extends StatelessWidget {
  final StockLevelModel level;
  final MaterialItem? material;
  final VoidCallback? onAdjust;

  const _StockRow({required this.level, required this.material, required this.onAdjust});

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(material?.name ?? 'Material #${level.materialId}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  '${level.qtyOnHand ?? 0} ${material?.unit ?? ''}'.trim(),
                  style: const TextStyle(fontSize: 14, color: AppTheme.brandBlue, fontWeight: FontWeight.w700),
                ),
                if (level.incomingToday > 0) ...[
                  const SizedBox(height: 2),
                  Text('Masuk hari ini: ${level.incomingToday} ${material?.unit ?? ''}'.trim(),
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
