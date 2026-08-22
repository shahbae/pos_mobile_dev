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

  /// Penanda permintaan aktif. Setiap `load` menaikkannya; respons dari
  /// permintaan lama yang datang belakangan dibuang supaya tidak menimpa
  /// hasil refresh yang lebih baru.
  int _reqId = 0;

  TransactionHistoryNotifier(this.repo) : super(TransactionHistoryState());

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  /// `reset: true` (tarik-refresh) selalu dijalankan, bahkan saat masih ada
  /// permintaan berjalan — kalau ditolak diam-diam, kasir menarik refresh dan
  /// tidak terjadi apa-apa, persis keluhan "datanya masih yang lama".
  Future<void> load({bool reset = false}) async {
    if (!reset && (state.loading || !state.hasMore)) return;

    final req = ++_reqId;
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

      // Provider autoDispose bisa sudah di-dispose saat request async selesai
      // (mis. user pindah halaman) — jangan sentuh state kalau sudah mati.
      // Respons usang (sudah ada load lebih baru) juga diabaikan.
      if (!mounted || req != _reqId) return;

      // Pengaman: pastikan hanya POS yang tampil walau server mengabaikan
      // filter `type`. hasMore dihitung dari jumlah baris mentah/halaman
      // (itu yang menentukan ada-tidaknya halaman berikutnya di server).
      final posItems = result.items.where((t) => t.isPos).toList();
      final hasMore = result.items.length == 20;

      state = state.copyWith(
        items: reset ? posItems : [...state.items, ...posItems],
        loading: false,
        hasMore: hasMore,
        page: page + 1,
      );

      // Halaman ini habis tersaring non-POS tapi server masih punya halaman
      // lain: lanjut ambil sendiri, jangan biarkan list kosong dengan spinner
      // yang menunggu scroll yang tidak akan pernah terjadi.
      if (posItems.isEmpty && hasMore) {
        await load();
      }
    } catch (e) {
      if (!mounted || req != _reqId) return;
      state = state.copyWith(loading: false);
      // Handle error if needed
    }
  }
}

final paymentDetailProvider = FutureProvider.family<List<PaymentModel>, int>((ref, transactionId) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getPayments(transactionId);
});
