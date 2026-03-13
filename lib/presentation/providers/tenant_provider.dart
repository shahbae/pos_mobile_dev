import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/tenant_model.dart';
import 'package:pos_mobile/data/repositories/tenant_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';

final tenantRepositoryProvider = Provider<TenantRepository>((ref) {
  final api = ref.watch(apiProvider);
  return TenantRepository(api);
});

final tenantProvider = FutureProvider<TenantModel>((ref) async {
  final repo = ref.watch(tenantRepositoryProvider);
  return await repo.getMyTenant();
});
