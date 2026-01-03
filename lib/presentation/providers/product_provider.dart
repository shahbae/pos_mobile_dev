import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/services/api_provider.dart';

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
