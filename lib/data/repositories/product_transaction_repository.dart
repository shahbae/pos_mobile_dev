import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/product_transaction_model.dart';
import 'package:pos_mobile/data/services/api_services.dart';
import 'package:flutter/foundation.dart';

import 'package:pos_mobile/data/services/api_provider.dart';

final productTransactionRepositoryProvider = Provider<ProductTransactionRepository>((ref) {
  final api = ref.watch(apiProvider);
  return ProductTransactionRepository(api);
});

class ProductTransactionRepository {
  final ApiService api;
  ProductTransactionRepository(this.api);

  Future<ProductTransactionResponse> createTransaction(ProductTransactionRequest request) async {
    try {
      debugPrint('[TransactionRepo] POST /product-transactions body: ${request.toJson()}');
      final res = await api.dio.post(
        '/product-transactions',
        data: request.toJson(),
      );

      debugPrint('[TransactionRepo] Response: ${res.data}');
      return ProductTransactionResponse.fromJson(res.data);
    } on DioException catch (e) {
      debugPrint('[TransactionRepo] DioError ${e.response?.statusCode}: ${e.response?.data}');
      final data = e.response?.data;
      final msg = (data is Map) ? (data['message'] ?? data['error']) : null;
      throw msg ?? 'Gagal membuat transaksi (${e.response?.statusCode ?? e.message})';
    }
  }
}
