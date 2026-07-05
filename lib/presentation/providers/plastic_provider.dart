import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/plastic_model.dart';
import 'package:pos_mobile/data/models/plastic_stock_model.dart';
import 'package:pos_mobile/data/models/plastic_stock_movement_model.dart';
import 'package:pos_mobile/data/repositories/plastic_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';

final plasticRepositoryProvider = Provider<PlasticRepository>((ref) {
  return PlasticRepository(ref.watch(apiProvider));
});

/// Daftar plastik aktif untuk dipakai di POS (picker kemasan) & audit/pembelian.
final plasticListProvider = FutureProvider<List<Plastic>>((ref) async {
  return ref.watch(plasticRepositoryProvider).getPlastics(activeOnly: true);
});

/// Daftar saldo stok plastik (halaman Stok Plastik / adjust).
final plasticStockListProvider = FutureProvider.autoDispose<List<PlasticStock>>((ref) async {
  return ref.watch(plasticRepositoryProvider).getPlasticStock();
});

/// Riwayat mutasi stok plastik. Param: plastic_id (null = semua).
final plasticStockMovementListProvider =
    FutureProvider.autoDispose.family<List<PlasticStockMovement>, int?>((ref, plasticId) async {
  return ref.watch(plasticRepositoryProvider).getPlasticStockMovements(plasticId: plasticId);
});
