import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/product_model.dart';
import 'package:pos_mobile/data/models/product_variant_model.dart';
import 'package:pos_mobile/data/repositories/product_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';

/// Repository Provider
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final api = ref.watch(apiProvider);
  return ProductRepository(api);
});

/// Daftar produk `freeable` (untuk picker item gratis promo), bisa dicari.
/// Hanya produk dari kategori freeable yang dikembalikan.
final freeableProductsProvider =
    FutureProvider.autoDispose.family<List<Product>, String?>((ref, search) async {
  final repo = ref.watch(productRepositoryProvider);
  final list = await repo.getProducts(page: 1, limit: 50, search: search ?? "");
  return list.where((p) => p.categoryFreeable).toList();
});

/// Daftar variant aktif sebuah produk (dipakai POS saat produk ditekan).
/// Hasil di-cache per productId selama masih dipakai (mis. dipanggil ulang).
final productVariantsProvider =
    FutureProvider.autoDispose.family<List<ProductVariant>, int>((ref, productId) async {
  return ref.watch(productRepositoryProvider).getVariants(productId, activeOnly: true);
});
