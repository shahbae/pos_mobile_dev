import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/supplier_repository.dart';
import '../../data/services/api_provider.dart';
import '../../data/models/supplier_model.dart';

final supplierRepositoryProvider = Provider((ref) {
  final api = ref.watch(apiProvider);
  return SupplierRepository(api);
});

final supplierListProvider = FutureProvider<List<Supplier>>((ref) async {
  final repo = ref.watch(supplierRepositoryProvider);
  return repo.getSuppliers();
});
