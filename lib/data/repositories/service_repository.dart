import 'package:flutter/foundation.dart';
import '../services/api_services.dart';
import '../models/service_model.dart';

class ServiceRepository {
  final ApiService api;
  ServiceRepository(this.api);

  Future<List<ServiceModel>> getServices({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    final res = await api.dio.get(
      '/services',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );

    debugPrint('[ServiceRepo] status=${res.statusCode} body=${res.data}');

    final data = res.data['data'];
    if (data == null) return [];

    if (data is List) {
      return data.map((e) => ServiceModel.fromJson(e)).toList();
    } else if (data is Map<String, dynamic>) {
      return [ServiceModel.fromJson(data)];
    }

    return [];
  }

  Future<void> createService(Map<String, dynamic> data) async {
    await api.dio.post('/services', data: data);
  }

  Future<void> updateService(int id, Map<String, dynamic> data) async {
    await api.dio.put('/services/$id', data: data);
  }

  Future<void> deleteService(int id) async {
    await api.dio.delete('/services/$id');
  }
}
