import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/employee_model.dart';
import 'package:pos_mobile/data/services/api_provider.dart';
import 'package:pos_mobile/data/services/api_services.dart';

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  final api = ref.watch(apiProvider);
  return EmployeeRepository(api);
});

class EmployeeRepository {
  final ApiService api;
  EmployeeRepository(this.api);

  Future<List<Employee>> getEmployees() async {
    final res = await api.dio.get('/employees');
    final List<dynamic> data = res.data['data'] ?? [];
    return data.map((i) => Employee.fromJson(i)).toList();
  }

  Future<Employee> createEmployee(EmployeeRequest request) async {
    final res = await api.dio.post('/employees', data: request.toJson());
    return Employee.fromJson(res.data['data']);
  }

  Future<Employee> updateEmployee(int id, EmployeeRequest request) async {
    final res = await api.dio.put('/employees/$id', data: request.toJson());
    return Employee.fromJson(res.data['data']);
  }

  Future<void> deleteEmployee(int id) async {
    await api.dio.delete('/employees/$id');
  }
}
