import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/kitchen_order_model.dart';
import 'package:pos_mobile/data/services/api_provider.dart';
import 'package:pos_mobile/data/services/api_services.dart';
import 'package:pos_mobile/data/services/sse_client.dart';

final kitchenRepositoryProvider = Provider<KitchenRepository>((ref) {
  return KitchenRepository(ref.watch(apiProvider));
});

/// Akses endpoint monitoring pesanan (KDS) di BE.
///
/// Cabang: BE mengunci non-owner ke cabang di token. Owner yang belum
/// switch cabang wajib mengirim `branch_id`, kalau tidak dijawab 400
/// ("branch_id is required").
class KitchenRepository {
  final ApiService api;
  KitchenRepository(this.api);

  /// Snapshot pesanan aktif — INI sumber kebenaran layar, bukan stream.
  Future<List<KitchenOrder>> listActive({int? branchId}) async {
    try {
      final res = await api.dio.get(
        '/kds/orders',
        queryParameters: {
          'status': kitchenActiveStatuses.join(','),
          if (branchId != null) 'branch_id': branchId,
        },
      );

      final data = res.data is Map ? res.data['data'] : res.data;
      if (data is! List) return [];

      return data
          .whereType<Map>()
          .map((e) => KitchenOrder.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      debugPrint('[KitchenRepo] listActive ${e.response?.statusCode}: '
          '${e.response?.data}');
      throw _message(e, 'Gagal memuat daftar pesanan');
    }
  }

  /// Pindahkan pesanan ke status dapur berikutnya.
  Future<KitchenOrder> updateStatus(int orderId, String status) async {
    try {
      final res = await api.dio.patch(
        '/kds/orders/$orderId/status',
        data: {'status': status},
      );
      final data = res.data is Map ? res.data['data'] : res.data;
      return KitchenOrder.fromJson(Map<String, dynamic>.from(data as Map));
    } on DioException catch (e) {
      debugPrint('[KitchenRepo] updateStatus($orderId,$status) '
          '${e.response?.statusCode}: ${e.response?.data}');
      switch (e.response?.statusCode) {
        case 404:
          throw 'Pesanan tidak ditemukan di cabang ini';
        case 422:
          throw 'Pesanan belum lunas — dapur belum boleh mengerjakannya';
        default:
          throw _message(e, 'Gagal mengubah status pesanan');
      }
    }
  }

  /// Buka stream SSE pesanan cabang. Pemanggil bertanggung jawab memanggil
  /// `connect()` dan `dispose()`.
  SseClient openStream({
    int? branchId,
    void Function(bool connected)? onStateChanged,
    Future<void> Function()? onUnauthorized,
  }) {
    return SseClient(
      dio: api.dio,
      path: '/kds/stream',
      queryParameters: {if (branchId != null) 'branch_id': branchId},
      onStateChanged: onStateChanged,
      onUnauthorized: onUnauthorized,
    );
  }

  String _message(DioException e, String fallback) {
    final d = e.response?.data;
    final msg = (d is Map) ? (d['message'] ?? d['error']) : null;
    return msg?.toString() ??
        '$fallback (${e.response?.statusCode ?? e.message})';
  }
}
