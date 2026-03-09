import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/stock_movement_repository.dart';
import '../../data/services/api_provider.dart';
import '../../data/models/stock_movement_model.dart';

final stockMovementRepositoryProvider = Provider<StockMovementRepository>((ref) {
  final api = ref.watch(apiProvider);
  return StockMovementRepository(api);
});

// Used to fetch stock movements. Can pass a product ID.
final stockMovementListProvider =
    FutureProvider.family<List<StockMovementModel>, int?>((ref, productId) async {
  final repo = ref.watch(stockMovementRepositoryProvider);
  return repo.getStockMovements(productId: productId);
});
