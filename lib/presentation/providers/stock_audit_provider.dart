import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/stock_audit_model.dart';
import 'package:pos_mobile/data/repositories/stock_audit_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';

final stockAuditRepositoryProvider = Provider<StockAuditRepository>((ref) {
  return StockAuditRepository(ref.watch(apiProvider));
});

final stockAuditListProvider = FutureProvider.autoDispose<List<StockAudit>>((ref) async {
  return ref.watch(stockAuditRepositoryProvider).getAudits();
});

final stockAuditDetailProvider =
    FutureProvider.autoDispose.family<StockAudit, int>((ref, id) async {
  return ref.watch(stockAuditRepositoryProvider).getAudit(id);
});
