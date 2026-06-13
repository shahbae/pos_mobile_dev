import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/stock_movement_repository.dart';
import '../../data/services/api_provider.dart';
import '../../data/models/stock_movement_model.dart';

final stockMovementRepositoryProvider = Provider<StockMovementRepository>((ref) {
  final api = ref.watch(apiProvider);
  return StockMovementRepository(api);
});

// Ambil mutasi stok (material-level). Param opsional: material_id.
final stockMovementListProvider =
    FutureProvider.family<List<StockMovementModel>, int?>((ref, materialId) async {
  final repo = ref.watch(stockMovementRepositoryProvider);
  return repo.getStockMovements(materialId: materialId);
});
