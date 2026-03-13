import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/transaction_history_model.dart';
import 'package:pos_mobile/data/repositories/transaction_history_repository.dart';

class TransactionHistoryState {
  final List<TransactionHistoryModel> items;
  final bool loading;
  final bool hasMore;
  final int page;
  final String? transactionType;
  final DateTime? from;
  final DateTime? to;

  TransactionHistoryState({
    this.items = const [],
    this.loading = false,
    this.hasMore = true,
    this.page = 1,
    this.transactionType,
    this.from,
    this.to,
  });

  TransactionHistoryState copyWith({
    List<TransactionHistoryModel>? items,
    bool? loading,
    bool? hasMore,
    int? page,
    String? transactionType,
    DateTime? from,
    DateTime? to,
  }) {
    return TransactionHistoryState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      transactionType: transactionType ?? this.transactionType,
      from: from ?? this.from,
      to: to ?? this.to,
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

    try {
      final result = await repo.getTransactions(
        page: page,
        limit: 20,
        transactionType: state.transactionType,
        from: state.from != null ? _formatDate(state.from!) : null,
        to: state.to != null ? _formatDate(state.to!) : null,
      );

      state = state.copyWith(
        items: reset ? result.items : [...state.items, ...result.items],
        loading: false,
        hasMore: result.items.length == 20,
        page: page + 1,
      );
    } catch (e) {
      state = state.copyWith(loading: false);
      // Handle error if needed
    }
  }

  void setFilter({String? transactionType, DateTime? from, DateTime? to}) {
    state = state.copyWith(
      transactionType: transactionType,
      from: from,
      to: to,
    );
    load(reset: true);
  }

  void resetFilters() {
    state = TransactionHistoryState();
    load(reset: true);
  }
}

final paymentDetailProvider = FutureProvider.family<List<PaymentModel>, int>((ref, transactionId) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getPayments(transactionId);
});
