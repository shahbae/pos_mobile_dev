import '../services/api_services.dart';
import '../models/supplier_model.dart';

class SupplierRepository {
  final ApiService api;

  SupplierRepository(this.api);

  Future<List<Supplier>> getSuppliers() async {
    final res = await api.dio.get('/suppliers');

    final List data = res.data['data'];

    return data.map((e) => Supplier.fromJson(e)).toList();
  }

  Future<void> createSupplier(Map<String, dynamic> body) async {
    await api.dio.post('/suppliers', data: body);
  }

  Future<void> updateSupplier(String id, Map<String, dynamic> body) async {
    await api.dio.put('/suppliers/$id', data: body);
  }
}
