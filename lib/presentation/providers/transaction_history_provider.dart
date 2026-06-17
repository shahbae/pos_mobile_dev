import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/transaction_history_model.dart';
import 'package:pos_mobile/data/repositories/transaction_history_repository.dart';

class TransactionHistoryState {
  final List<TransactionHistoryModel> items;
  final bool loading;
  final bool hasMore;
  final int page;

  TransactionHistoryState({
    this.items = const [],
    this.loading = false,
    this.hasMore = true,
    this.page = 1,
  });

  TransactionHistoryState copyWith({
    List<TransactionHistoryModel>? items,
    bool? loading,
    bool? hasMore,
    int? page,
  }) {
    return TransactionHistoryState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
    );
  }
}

final transactionHistoryProvider =
    StateNotifierProvider.autoDispose<TransactionHistoryNotifier, TransactionHistoryState>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return TransactionHistoryNotifier(repo)..load(reset: true);
});

class TransactionHistoryNotifier extends StateNotifier<TransactionHistoryState> {
  final TransactionRepository repo;

  TransactionHistoryNotifier(this.repo) : super(TransactionHistoryState());

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> load({bool reset = false}) async {
    if (state.loading || (!state.hasMore && !reset)) return;

    final page = reset ? 1 : state.page;
    state = state.copyWith(loading: true);

    // Riwayat dibatasi: hanya transaksi POS, hanya hari ini.
    final today = _formatDate(DateTime.now());

    try {
      final result = await repo.getTransactions(
        page: page,
        limit: 20,
        type: 'pos',
        from: today,
        to: today,
      );

      // Pengaman: pastikan hanya POS yang tampil walau server mengabaikan
      // filter `type`. hasMore tetap dihitung dari jumlah baris mentah/halaman.
      final posItems = result.items.where((t) => t.isPos).toList();

      state = state.copyWith(
        items: reset ? posItems : [...state.items, ...posItems],
        loading: false,
        hasMore: result.items.length == 20,
        page: page + 1,
      );
    } catch (e) {
      state = state.copyWith(loading: false);
      // Handle error if needed
    }
  }
}

final paymentDetailProvider = FutureProvider.family<List<PaymentModel>, int>((ref, transactionId) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getPayments(transactionId);
});
