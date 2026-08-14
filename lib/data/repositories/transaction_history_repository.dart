import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:pos_mobile/data/models/transaction_history_model.dart';
import 'package:pos_mobile/data/services/api_services.dart';
import 'package:pos_mobile/data/services/api_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_scope.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  // Ikut lahir ulang saat pindah cabang — lihat [branchScopeProvider].
  ref.watch(branchScopeProvider);
  final api = ref.watch(apiProvider);
  return TransactionRepository(api);
});

class TransactionRepository {
  final ApiService api;
  TransactionRepository(this.api);

  Future<TransactionHistoryResponse> getTransactions({
    int page = 1,
    int limit = 20,
    String? type, // pos | purchase | expense
    String? from,
    String? to,
    int? shiftId,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (type != null) 'type': type,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (shiftId != null) 'shift_id': shiftId,
    };

    final res = await api.dio.get('/transactions', queryParameters: query);

    return TransactionHistoryResponse.fromJson(res.data);
  }

  Future<List<PaymentModel>> getPayments(int transactionId) async {
    try {
      final res = await api.dio.get('/transactions/$transactionId/payments');
      final body = res.data;

      // Toleran terhadap beberapa bentuk: { data: [...] }, { data: { items: [...] } },
      // { data: {...} } (objek tunggal), atau langsung list di root.
      dynamic data = (body is Map) ? (body['data'] ?? body['items']) : body;
      if (data is Map) data = data['items'] ?? [data];
      if (data is! List) return [];

      return data
          .whereType<Map>()
          .map((i) => PaymentModel.fromJson(Map<String, dynamic>.from(i)))
          .toList();
    } on DioException catch (e) {
      debugPrint('[TransactionRepo] getPayments($transactionId) '
          '${e.response?.statusCode}: ${e.response?.data}');
      final d = e.response?.data;
      final msg = (d is Map) ? (d['message'] ?? d['error']) : null;
      throw msg?.toString() ??
          'Gagal mengambil data pembayaran (${e.response?.statusCode ?? e.message})';
    }
  }
}
