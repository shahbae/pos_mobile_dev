import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/stock_level_repository.dart';
import '../../data/services/api_provider.dart';
import '../../data/models/stock_level_model.dart';

final stockLevelRepositoryProvider = Provider<StockLevelRepository>((ref) {
  final api = ref.watch(apiProvider);
  return StockLevelRepository(api);
});

final stockLevelProvider = FutureProvider.family<StockLevelModel?, int>((ref, productId) async {
  final repo = ref.watch(stockLevelRepositoryProvider);
  return repo.getStockLevel(productId);
});

/// Daftar stok semua material (untuk halaman Stok Material / adjust).
final materialStockLevelsProvider =
    FutureProvider.autoDispose<List<StockLevelModel>>((ref) async {
  return ref.watch(stockLevelRepositoryProvider).getMaterialStockLevels();
});
