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
    final res = await api.dio.post(
      '/product-transactions',
      data: request.toJson(),
    );

    debugPrint('[TransactionRepo] Response: ${res.data}');
    return ProductTransactionResponse.fromJson(res.data);
  }
}
