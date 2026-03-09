import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/services/api_provider.dart';
import '../../data/models/expense_model.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final api = ref.watch(apiProvider);
  return ExpenseRepository(api);
});

// Param: (from, to) — nullable strings, Records have structural equality in Dart 3
final expenseListProvider = FutureProvider.family<List<ExpenseModel>, (String?, String?)>((ref, params) async {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getExpenses(
    from: params.$1,
    to: params.$2,
  );
});

final expenseDetailProvider = FutureProvider.family<ExpenseModel?, int>((ref, id) async {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getExpenseDetail(id);
});
