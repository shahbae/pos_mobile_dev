import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/product_variant_model.dart';
import 'package:pos_mobile/data/repositories/product_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';

/// Repository Provider
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final api = ref.watch(apiProvider);
  return ProductRepository(api);
});

/// Daftar variant aktif sebuah produk (dipakai POS saat produk ditekan).
/// Hasil di-cache per productId selama masih dipakai (mis. dipanggil ulang).
final productVariantsProvider =
    FutureProvider.autoDispose.family<List<ProductVariant>, int>((ref, productId) async {
  return ref.watch(productRepositoryProvider).getVariants(productId, activeOnly: true);
});
