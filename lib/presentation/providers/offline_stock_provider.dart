import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/core/offline_stock.dart';
import 'package:pos_mobile/data/models/product_model.dart';
import 'package:pos_mobile/presentation/providers/offline_provider.dart';
import 'package:pos_mobile/presentation/providers/pos_catalog_provider.dart';

/// Tanda siap menu menurut hitungan stok HP selama mode offline (revisi
/// 28 Nov): menu yang bahannya tidak cukup untuk satu porsi jadi abu-abu, sama
/// seperti tanda "habis" dari server saat online.
class OfflineReadiness {
  final StockRules rules;
  final Map<String, int> available;

  const OfflineReadiness(this.rules, this.available);

  /// Salinan [products] dengan tanda siap hasil hitungan HP. Produk bervarian
  /// siap bila minimal satu variannya siap — aturan yang sama dengan server.
  List<Product> apply(List<Product> products) => [
    for (final p in products)
      if (p.variants.isEmpty)
        p.withReadiness(
          productReady: rules.recipeReady(productId: p.id, available: available),
        )
      else
        _withVariants(p),
  ];

  Product _withVariants(Product p) {
    final ready = <int, bool>{
      for (final v in p.variants) v.id: rules.recipeReady(productId: p.id, variantId: v.id, available: available),
    };
    return p.withReadiness(productReady: ready.values.any((r) => r), variantReady: ready);
  }
}

/// null = mode online (tanda siap dari server apa adanya), atau HP belum punya
/// angka stok / aturan potong dari server.
final offlineReadinessProvider = FutureProvider.autoDispose<OfflineReadiness?>((ref) async {
  final offline = ref.watch(offlineProvider.select((s) => (s.active, s.pending, s.failed, s.stockRevision)));
  if (!offline.$1) return null;
  final catalog = ref.watch(posCatalogProvider.select((s) => s.catalog));
  final rules = catalog?.stockRules;
  if (catalog == null || rules == null) return null;
  final stock = await ref.read(offlineProvider.notifier).localStock(catalog);
  if (stock == null) return null;
  return OfflineReadiness(rules, stock.available);
});
