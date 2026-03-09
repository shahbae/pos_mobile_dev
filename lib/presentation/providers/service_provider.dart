import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/service_repository.dart';
import '../../data/services/api_provider.dart';
import '../../data/models/service_model.dart';

final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  final api = ref.watch(apiProvider);
  return ServiceRepository(api);
});

final serviceListProvider =
    FutureProvider.family<List<ServiceModel>, String?>((ref, search) async {
  final repo = ref.watch(serviceRepositoryProvider);
  return repo.getServices(page: 1, limit: 10, search: search ?? "");
});
