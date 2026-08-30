import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/shipment_model.dart';
import 'package:pos_mobile/data/repositories/shipment_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_scope.dart';

final shipmentRepositoryProvider = Provider<ShipmentRepository>((ref) {
  // Ikut lahir ulang saat pindah cabang — lihat [branchScopeProvider].
  ref.watch(branchScopeProvider);
  return ShipmentRepository(ref.watch(apiProvider));
});

/// Daftar kiriman cabang aktif. Yang masih di jalan selalu di atas (urutannya
/// diatur BE), jadi jangan diurutkan ulang di sini.
final shipmentListProvider =
    FutureProvider.autoDispose<List<Shipment>>((ref) async {
  return ref.watch(shipmentRepositoryProvider).getShipments();
});

final shipmentDetailProvider =
    FutureProvider.autoDispose.family<Shipment, int>((ref, id) async {
  return ref.watch(shipmentRepositoryProvider).getShipment(id);
});

/// Berapa kiriman yang menunggu ditindak. Dipakai menandai menunya supaya
/// barang yang sudah sampai tidak menganggur karena tidak ada yang membuka
/// layarnya.
final pendingShipmentCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(shipmentListProvider).maybeWhen(
        data: (list) => list.where((s) => s.isOnTheWay).length,
        orElse: () => 0,
      );
});
