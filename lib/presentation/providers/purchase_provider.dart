import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/purchase_repository.dart';
import '../../data/services/api_provider.dart';
import '../../data/models/purchase_model.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  final api = ref.watch(apiProvider);
  return PurchaseRepository(api);
});

final purchaseListProvider =
    FutureProvider.family<List<PurchaseModel>, String?>((ref, search) async {
  final repo = ref.watch(purchaseRepositoryProvider);
  return repo.getPurchases(page: 1, limit: 10, search: search ?? "");
});

final purchaseDetailProvider =
    FutureProvider.family<PurchaseModel, int>((ref, id) async {
  final repo = ref.watch(purchaseRepositoryProvider);
  return repo.getPurchaseDetail(id);
});
