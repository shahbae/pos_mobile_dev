import 'package:flutter/foundation.dart';
import '../services/api_services.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final ApiService api;
  ExpenseRepository(this.api);

  Future<List<ExpenseModel>> getExpenses({
    int page = 1,
    int limit = 50,
    String? from,
    String? to,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'page': page,
        'limit': limit,
      };
      if (from != null && from.isNotEmpty) queryParams['from'] = from;
      if (to != null && to.isNotEmpty) queryParams['to'] = to;

      final res = await api.dio.get('/expenses', queryParameters: queryParams);
      debugPrint('[ExpenseRepository] status=${res.statusCode} body=${res.data}');

      final List items = res.data['data']['items'] ?? [];
      return items.map((e) => ExpenseModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[ExpenseRepository] Error fetching expenses: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data) async {
    final res = await api.dio.post('/expenses', data: data);
    return res.data;
  }

  Future<ExpenseModel?> getExpenseDetail(int id) async {
    try {
      final res = await api.dio.get('/expenses/$id');
      final data = res.data['data'];
      if (data == null) return null;
      return ExpenseModel.fromJson(data);
    } catch (e) {
      debugPrint('[ExpenseRepository] Error fetching detail: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> updateExpense(int id, Map<String, dynamic> data) async {
    final res = await api.dio.put('/expenses/$id', data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> deleteExpense(int id) async {
    final res = await api.dio.delete('/expenses/$id');
    return res.data;
  }
}
