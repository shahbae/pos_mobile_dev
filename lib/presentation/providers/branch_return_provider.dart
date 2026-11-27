import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/branch_return_model.dart';
import 'package:pos_mobile/data/repositories/branch_return_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';

final branchReturnRepositoryProvider = Provider<BranchReturnRepository>((ref) {
  return BranchReturnRepository(ref.watch(apiProvider));
});

/// Barang yang boleh diretur; autoDispose supaya stoknya segar tiap layar dibuka.
final branchReturnItemsProvider = FutureProvider.autoDispose<List<BranchReturnItem>>((ref) {
  return ref.watch(branchReturnRepositoryProvider).items();
});

final branchReturnHistoryProvider = FutureProvider.autoDispose<List<BranchReturnDoc>>((ref) {
  return ref.watch(branchReturnRepositoryProvider).history();
});
