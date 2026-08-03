import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/plastic_model.dart';
import 'package:pos_mobile/data/models/plastic_stock_model.dart';
import 'package:pos_mobile/data/models/plastic_stock_movement_model.dart';
import 'package:pos_mobile/data/repositories/plastic_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';
import 'package:pos_mobile/presentation/providers/master_data_cache.dart';

final plasticRepositoryProvider = Provider<PlasticRepository>((ref) {
  return PlasticRepository(ref.watch(apiProvider));
});

/// Daftar plastik aktif untuk dipakai di POS (picker kemasan) & audit/pembelian.
/// Di-cache ber-TTL: plastik baru dari admin tetap muncul tanpa restart app,
/// tanpa menembak request tiap kali halaman checkout dibuka.
final plasticListProvider = FutureProvider.autoDispose<List<Plastic>>((ref) async {
  cacheFor(ref);
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
