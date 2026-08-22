import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/stock_audit_model.dart';
import 'package:pos_mobile/data/repositories/stock_audit_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_scope.dart';

final stockAuditRepositoryProvider = Provider<StockAuditRepository>((ref) {
  // Ikut lahir ulang saat pindah cabang — lihat [branchScopeProvider].
  ref.watch(branchScopeProvider);
  return StockAuditRepository(ref.watch(apiProvider));
});

final stockAuditListProvider = FutureProvider.autoDispose<List<StockAudit>>((ref) async {
  return ref.watch(stockAuditRepositoryProvider).getAudits();
});

final stockAuditDetailProvider =
    FutureProvider.autoDispose.family<StockAudit, int>((ref, id) async {
  return ref.watch(stockAuditRepositoryProvider).getAudit(id);
});

/// Item yang boleh diaudit di cabang aktif (BE 2026-08-08 §1). Sengaja TIDAK
/// di-cache: owner bisa mengubah centangnya kapan saja dan form opname harus
/// selalu memakai daftar terbaru — kalau basi, POST-nya kena 422.
final auditableItemsProvider =
    FutureProvider.autoDispose<List<AuditableItem>>((ref) async {
  // Ikut cabang aktif: ganti cabang → daftar & snapshot stoknya ikut berubah.
  final branchId = ref.watch(authProvider).branchId;
  return ref.watch(stockAuditRepositoryProvider).getAuditableItems(branchId: branchId);
});
