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

/// Provider list produk (support search param)
final productListProvider = FutureProvider.family<List<Product>, String?>((
  ref,
  search,
) async {
  final repo = ref.watch(productRepositoryProvider);

  return repo.getProducts(page: 1, limit: 10, search: search ?? "");
});

/// Daftar variant aktif sebuah produk (dipakai POS saat produk ditekan).
/// Hasil di-cache per productId selama masih dipakai (mis. dipanggil ulang).
final productVariantsProvider =
    FutureProvider.autoDispose.family<List<ProductVariant>, int>((ref, productId) async {
  return ref.watch(productRepositoryProvider).getVariants(productId, activeOnly: true);
});
