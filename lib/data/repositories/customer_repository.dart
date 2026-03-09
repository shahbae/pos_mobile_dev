import 'package:flutter/foundation.dart';
import '../services/api_services.dart';
import '../models/customer_model.dart';

class CustomerRepository {
  final ApiService api;
  CustomerRepository(this.api);

  Future<List<Customer>> getCustomers({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    final res = await api.dio.get(
      '/customers',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );

    debugPrint('[CustomerRepo] status=${res.statusCode} body=${res.data}');

    final data = res.data['data'];
    
    // API might return data directly in a single object if there's only 1 item like in sample,
    // or as a list inside 'data'. Let's handle list explicitly:
    if (data == null) return [];
    
    if (data is List) {
      return data.map((e) => Customer.fromJson(e)).toList();
    } else if (data is Map<String, dynamic>) {
      // In case of single object wrapped in data
      return [Customer.fromJson(data)];
    }
    
    return [];
  }

  Future<void> createCustomer(Map<String, dynamic> data) async {
    await api.dio.post('/customers', data: data);
  }

  Future<void> updateCustomer(int id, Map<String, dynamic> data) async {
    await api.dio.put('/customers/$id', data: data);
  }

  Future<void> deleteCustomer(int id) async {
    await api.dio.delete('/customers/$id');
  }
}
