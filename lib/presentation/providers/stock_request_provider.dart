import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/stock_request_model.dart';
import 'package:pos_mobile/data/repositories/stock_request_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_scope.dart';

final stockRequestRepositoryProvider = Provider<StockRequestRepository>((ref) {
  // Ikut lahir ulang saat pindah cabang — lihat [branchScopeProvider].
  ref.watch(branchScopeProvider);
  return StockRequestRepository(ref.watch(apiProvider));
});

/// Daftar permintaan cabang aktif. Yang belum diputuskan gudang selalu di atas
/// (urutannya diatur BE), jadi jangan diurutkan ulang di sini.
final stockRequestListProvider =
    FutureProvider.autoDispose<List<StockRequest>>((ref) async {
  return ref.watch(stockRequestRepositoryProvider).getRequests();
});

final stockRequestDetailProvider =
    FutureProvider.autoDispose.family<StockRequest, int>((ref, id) async {
  return ref.watch(stockRequestRepositoryProvider).getRequest(id);
});

/// Katalog barang yang boleh diminta. Sengaja TIDAK di-cache: penandaan bahan
/// setengah jadi dan kemasannya diatur dari web admin dan bisa berubah kapan
/// saja. Kalau daftarnya basi, POST-nya kena 422.
final requestableItemsProvider =
    FutureProvider.autoDispose<List<RequestableItem>>((ref) async {
  return ref.watch(stockRequestRepositoryProvider).getRequestableItems();
});
