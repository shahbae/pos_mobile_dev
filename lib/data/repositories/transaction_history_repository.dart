import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/transaction_history_model.dart';
import 'package:pos_mobile/data/services/api_services.dart';
import 'package:pos_mobile/data/services/api_provider.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final api = ref.watch(apiProvider);
  return TransactionRepository(api);
});

class TransactionRepository {
  final ApiService api;
  TransactionRepository(this.api);

  Future<TransactionHistoryResponse> getTransactions({
    int page = 1,
    int limit = 20,
    String? transactionType,
    String? from,
    String? to,
  }) async {
    final res = await api.dio.get('/transactions', queryParameters: {
      'page': page,
      'limit': limit,
      if (transactionType != null) 'transaction_type': transactionType,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });

    return TransactionHistoryResponse.fromJson(res.data);
  }

  Future<List<PaymentModel>> getPayments(int transactionId) async {
    final res = await api.dio.get('/transactions/$transactionId/payments');
    final List<dynamic> data = res.data['data'] ?? [];
    return data.map((i) => PaymentModel.fromJson(i)).toList();
  }
}
