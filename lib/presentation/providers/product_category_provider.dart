import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/product_category_repository.dart';
import '../../data/services/api_provider.dart';
import '../../data/models/product_category_model.dart';
import 'package:pos_mobile/presentation/providers/branch_scope.dart';

final productCategoryRepositoryProvider = Provider<ProductCategoryRepository>((ref) {
  // Ikut lahir ulang saat pindah cabang — lihat [branchScopeProvider].
  ref.watch(branchScopeProvider);
  final api = ref.watch(apiProvider);
  return ProductCategoryRepository(api);
});

final productCategoryListProvider = FutureProvider.family<List<ProductCategory>, String?>((
  ref,
  search,
) async {
  final repo = ref.watch(productCategoryRepositoryProvider);

  return repo.getCategories(page: 1, limit: 10, search: search ?? "");
});
