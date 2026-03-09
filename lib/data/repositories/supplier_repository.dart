import 'package:flutter/foundation.dart';
import '../services/api_services.dart';
import '../models/supplier_model.dart';

class SupplierRepository {
  final ApiService api;

  SupplierRepository(this.api);

  Future<List<Supplier>> getSuppliers({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    final res = await api.dio.get(
      '/suppliers',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );

    debugPrint('[SupplierRepo] status=${res.statusCode} body=${res.data}');

    final data = res.data['data'];
    if (data == null) return [];

    return (data as List).map((e) => Supplier.fromJson(e)).toList();
  }

  Future<void> createSupplier(Map<String, dynamic> data) async {
    await api.dio.post('/suppliers', data: data);
  }

  Future<void> updateSupplier(int id, Map<String, dynamic> data) async {
    await api.dio.put('/suppliers/$id', data: data);
  }

  Future<void> deleteSupplier(int id) async {
    await api.dio.delete('/suppliers/$id');
  }
}
