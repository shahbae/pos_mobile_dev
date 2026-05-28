import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/branch_model.dart';
import 'package:pos_mobile/data/repositories/branch_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';

final branchRepositoryProvider = Provider<BranchRepository>((ref) {
  return BranchRepository(ref.watch(apiProvider));
});

final branchListProvider = FutureProvider<List<BranchModel>>((ref) async {
  return ref.read(branchRepositoryProvider).getBranches();
});

final currentBranchProvider = Provider<BranchModel?>((ref) {
  final branchId = ref.watch(authProvider).branchId;
  if (branchId == null) return null;
  final branches = ref.watch(branchListProvider).valueOrNull;
  if (branches == null) return null;
  try {
    return branches.firstWhere((b) => b.id == branchId);
  } catch (_) {
    return null;
  }
});

class BranchSwitchNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> switchBranch(int branchId) async {
    state = const AsyncLoading();
    try {
      await ref.read(branchRepositoryProvider).switchBranch(branchId);
      await ref.read(authProvider.notifier).reloadFromToken();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final branchSwitchProvider =
    AsyncNotifierProvider<BranchSwitchNotifier, void>(BranchSwitchNotifier.new);
