import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/supplier_repository.dart';
import '../../data/services/api_provider.dart';
import '../../data/models/supplier_model.dart';

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  final api = ref.watch(apiProvider);
  return SupplierRepository(api);
});

final supplierListProvider = FutureProvider.family<List<Supplier>, String?>((
  ref,
  search,
) async {
  final repo = ref.watch(supplierRepositoryProvider);

  return repo.getSuppliers(page: 1, limit: 10, search: search ?? "");
});
