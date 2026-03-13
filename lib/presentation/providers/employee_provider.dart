import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/employee_model.dart';
import 'package:pos_mobile/data/repositories/employee_repository.dart';

final employeeProvider = StateNotifierProvider<EmployeeNotifier, AsyncValue<List<Employee>>>((ref) {
  final repo = ref.watch(employeeRepositoryProvider);
  return EmployeeNotifier(repo);
});

class EmployeeNotifier extends StateNotifier<AsyncValue<List<Employee>>> {
  final EmployeeRepository repo;

  EmployeeNotifier(this.repo) : super(const AsyncValue.loading()) {
    loadEmployees();
  }

  Future<void> loadEmployees() async {
    state = const AsyncValue.loading();
    try {
      final employees = await repo.getEmployees();
      state = AsyncValue.data(employees);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> createEmployee(EmployeeRequest request) async {
    try {
      await repo.createEmployee(request);
      loadEmployees();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateEmployee(int id, EmployeeRequest request) async {
    try {
      await repo.updateEmployee(id, request);
      loadEmployees();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteEmployee(int id) async {
    try {
      await repo.deleteEmployee(id);
      loadEmployees();
      return true;
    } catch (e) {
      return false;
    }
  }
}
