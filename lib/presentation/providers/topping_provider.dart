import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/topping_model.dart';
import 'package:pos_mobile/data/models/topping_stock_model.dart';
import 'package:pos_mobile/data/models/topping_stock_movement_model.dart';
import 'package:pos_mobile/data/repositories/topping_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_scope.dart';

final toppingRepositoryProvider = Provider<ToppingRepository>((ref) {
  // Ikut lahir ulang saat pindah cabang — lihat [branchScopeProvider].
  ref.watch(branchScopeProvider);
  return ToppingRepository(ref.watch(apiProvider));
});

/// Daftar topping aktif untuk dipakai di POS (picker topping).
final toppingListProvider = FutureProvider<List<Topping>>((ref) async {
  return ref.watch(toppingRepositoryProvider).getToppings(activeOnly: true);
});

/// Daftar saldo stok topping (halaman Stok Topping / adjust).
final toppingStockListProvider = FutureProvider.autoDispose<List<ToppingStock>>((ref) async {
  return ref.watch(toppingRepositoryProvider).getToppingStock();
});

/// Riwayat mutasi stok topping. Param: topping_id (null = semua).
final toppingStockMovementListProvider =
    FutureProvider.autoDispose.family<List<ToppingStockMovement>, int?>((ref, toppingId) async {
  return ref.watch(toppingRepositoryProvider).getToppingStockMovements(toppingId: toppingId);
});
