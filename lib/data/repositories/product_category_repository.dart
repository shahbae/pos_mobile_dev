import 'package:flutter/foundation.dart';
import '../services/api_services.dart';
import '../models/product_category_model.dart';

class ProductCategoryRepository {
  final ApiService api;

  ProductCategoryRepository(this.api);

  Future<List<ProductCategory>> getCategories({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    final res = await api.dio.get(
      '/product-categories',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );

    debugPrint('[CategoryRepo] status=${res.statusCode} body=${res.data}');

    final data = res.data['data'];
    if (data == null) return [];

    return (data as List).map((e) => ProductCategory.fromJson(e)).toList();
  }

  Future<void> createCategory(Map<String, dynamic> data) async {
    await api.dio.post('/product-categories', data: data);
  }

  Future<void> updateCategory(int id, Map<String, dynamic> data) async {
    await api.dio.put('/product-categories/$id', data: data);
  }

  Future<void> deleteCategory(int id) async {
    await api.dio.delete('/product-categories/$id');
  }
}
