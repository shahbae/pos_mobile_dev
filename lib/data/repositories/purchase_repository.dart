import 'package:flutter/foundation.dart';
import '../services/api_services.dart';
import '../models/purchase_model.dart';

class PurchaseRepository {
  final ApiService api;
  PurchaseRepository(this.api);

  Future<List<PurchaseModel>> getPurchases({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    final res = await api.dio.get(
      '/purchases',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );

    debugPrint('[PurchaseRepo] status=${res.statusCode} body=${res.data}');

    final data = res.data['data'];
    if (data == null) return [];

    List listData = [];
    if (data is Map && data['items'] is List) {
      listData = data['items'];
    } else if (data is List) {
      listData = data;
    }

    return listData.map((e) => PurchaseModel.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> createPurchase(Map<String, dynamic> data) async {
    final res = await api.dio.post('/purchases', data: data);
    return res.data;
  }

  Future<PurchaseModel> getPurchaseDetail(int id) async {
    final res = await api.dio.get('/purchases/$id');
    return PurchaseModel.fromJson(res.data['data']);
  }
}
