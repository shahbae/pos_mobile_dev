import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/material_model.dart';
import 'package:pos_mobile/data/repositories/material_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_scope.dart';

final materialRepositoryProvider = Provider<MaterialRepository>((ref) {
  // Ikut lahir ulang saat pindah cabang — lihat [branchScopeProvider].
  ref.watch(branchScopeProvider);
  return MaterialRepository(ref.watch(apiProvider));
});

final materialListProvider = FutureProvider<List<MaterialItem>>((ref) async {
  return ref.watch(materialRepositoryProvider).getMaterials();
});
