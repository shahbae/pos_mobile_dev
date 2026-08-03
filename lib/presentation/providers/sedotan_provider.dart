import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/sedotan_model.dart';
import 'package:pos_mobile/data/models/sedotan_stock_model.dart';
import 'package:pos_mobile/data/models/sedotan_stock_movement_model.dart';
import 'package:pos_mobile/data/repositories/sedotan_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';
import 'package:pos_mobile/presentation/providers/master_data_cache.dart';

final sedotanRepositoryProvider = Provider<SedotanRepository>((ref) {
  return SedotanRepository(ref.watch(apiProvider));
});

/// Daftar sedotan aktif untuk dipakai di POS (picker) & audit/pembelian.
/// Di-cache ber-TTL dengan alasan yang sama seperti plasticListProvider.
final sedotanListProvider = FutureProvider.autoDispose<List<Sedotan>>((ref) async {
  cacheFor(ref);
  return ref.watch(sedotanRepositoryProvider).getSedotans(activeOnly: true);
});

/// Daftar saldo stok sedotan (halaman Stok Sedotan / adjust).
final sedotanStockListProvider = FutureProvider.autoDispose<List<SedotanStock>>((ref) async {
  return ref.watch(sedotanRepositoryProvider).getSedotanStock();
});

/// Riwayat mutasi stok sedotan. Param: sedotan_id (null = semua).
final sedotanStockMovementListProvider =
    FutureProvider.autoDispose.family<List<SedotanStockMovement>, int?>((ref, sedotanId) async {
  return ref.watch(sedotanRepositoryProvider).getSedotanStockMovements(sedotanId: sedotanId);
});
