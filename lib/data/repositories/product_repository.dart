import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../services/api_services.dart';

class ProductRepository {
  final ApiService api;
  ProductRepository(this.api);

  Future<List<Product>> getProducts({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    final res = await api.dio.get(
      '/products',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );

    debugPrint('[ProductRepo] status=${res.statusCode} body=${res.data}');

    final data = res.data['data'];
    if (data == null) return [];

    return (data as List).map((e) => Product.fromJson(e)).toList();
  }

  Future<void> createProduct(Map<String, dynamic> data) async {
    await api.dio.post('/products', data: data);
  }

  Future<void> updateProduct(int id, Map<String, dynamic> data) async {
    await api.dio.put('/products/$id', data: data);
  }

  Future<void> deleteProduct(int id) async {
    await api.dio.delete('/products/$id');
  }
}
