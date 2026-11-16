import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/branch_waste_model.dart';
import 'package:pos_mobile/data/repositories/branch_waste_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';

final branchWasteRepositoryProvider = Provider<BranchWasteRepository>((ref) {
  return BranchWasteRepository(ref.watch(apiProvider));
});

/// Barang cabang yang bisa dibuang. autoDispose supaya stoknya selalu segar
/// tiap layar dibuka: angka stok lama menyesatkan di layar yang justru
/// memotong stok.
final branchWasteItemsProvider = FutureProvider.autoDispose<List<BranchWasteItem>>((ref) {
  return ref.watch(branchWasteRepositoryProvider).items();
});
