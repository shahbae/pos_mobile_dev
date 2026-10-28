import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/allowance_model.dart';
import 'package:pos_mobile/data/repositories/allowance_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_scope.dart';
import 'package:pos_mobile/presentation/providers/paged_list_notifier.dart';

final allowanceRepositoryProvider = Provider<AllowanceRepository>((ref) {
  // Daftar penerima diurut per cabang token; ikut lahir ulang saat pindah
  // cabang — lihat [branchScopeProvider].
  ref.watch(branchScopeProvider);
  return AllowanceRepository(ref.watch(apiProvider));
});

/// Penerima jatah hari ini untuk checkout. Dimuat ulang tiap dibuka, karena
/// saldonya berubah oleh kasir lain.
final allowanceRecipientsProvider = FutureProvider.autoDispose<List<AllowanceRecipient>>((ref) {
  return ref.watch(allowanceRepositoryProvider).recipients();
});

/// Saldo jatah sendiri hari ini.
final myAllowanceProvider = FutureProvider.autoDispose<MyAllowance>((ref) {
  return ref.watch(allowanceRepositoryProvider).mine();
});

/// Pesanan jatah yang pernah diterima, terbaru dulu.
final myAllowanceOrdersProvider =
    StateNotifierProvider.autoDispose<PagedListNotifier<AllowanceOrder>, PagedListState<AllowanceOrder>>((ref) {
  final repo = ref.watch(allowanceRepositoryProvider);
  return PagedListNotifier<AllowanceOrder>(repo.myOrders, pageLimit: 20);
});
