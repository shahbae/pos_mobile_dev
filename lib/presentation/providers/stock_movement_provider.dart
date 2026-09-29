import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/stock_movement_repository.dart';
import '../../data/services/api_provider.dart';
import '../../data/models/stock_movement_model.dart';
import 'package:pos_mobile/presentation/providers/branch_scope.dart';
import 'package:pos_mobile/presentation/providers/movement_list_notifier.dart';

final stockMovementRepositoryProvider = Provider<StockMovementRepository>((ref) {
  // Ikut lahir ulang saat pindah cabang — lihat [branchScopeProvider].
  ref.watch(branchScopeProvider);
  final api = ref.watch(apiProvider);
  return StockMovementRepository(api);
});

/// Riwayat mutasi bahan per halaman. Param: material_id (null = semua).
final stockMovementListProvider = StateNotifierProvider.autoDispose.family<
    MovementListNotifier<StockMovementModel>, MovementListState<StockMovementModel>, int?>(
  (ref, materialId) {
    final repo = ref.watch(stockMovementRepositoryProvider);
    return MovementListNotifier<StockMovementModel>(
      (page, limit) => repo.getStockMovementPage(materialId: materialId, page: page, limit: limit),
    );
  },
);
