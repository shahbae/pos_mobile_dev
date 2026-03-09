import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/services/api_provider.dart';
import '../../data/models/customer_model.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final api = ref.watch(apiProvider);
  return CustomerRepository(api);
});

final customerListProvider = FutureProvider.family<List<Customer>, String?>((
  ref,
  search,
) async {
  final repo = ref.watch(customerRepositoryProvider);
  return repo.getCustomers(page: 1, limit: 10, search: search ?? "");
});
