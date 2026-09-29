import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/page_result.dart';

/// Ukuran halaman bawaan daftar riwayat (mutasi, opname) di aplikasi.
const defaultPageLimit = 30;

class PagedListState<T> {
  final List<T> items;
  final int total;
  final bool loading;
  final bool hasMore;
  final int nextPage;

  /// Kegagalan permintaan terakhir. Diisi → daftar berhenti memuat otomatis
  /// sampai pengguna menekan "Coba lagi", supaya tidak mengulang tanpa henti
  /// di jaringan yang sedang putus.
  final Object? error;

  const PagedListState({
    this.items = const [],
    this.total = 0,
    this.loading = false,
    this.hasMore = true,
    this.nextPage = 1,
    this.error,
  });

  bool get isFirstLoad =>
      items.isEmpty && (loading || error == null && hasMore);
}

/// Memuat daftar riwayat (mutasi, opname) per halaman: halaman 1 saat dibuat,
/// halaman berikutnya lewat [loadMore], mulai ulang lewat [refresh].
class PagedListNotifier<T> extends StateNotifier<PagedListState<T>> {
  final Future<PageResult<T>> Function(int page, int limit) _fetch;
  final int pageLimit;

  /// Penanda permintaan aktif; respons dari permintaan yang sudah digantikan
  /// (mis. tarik-refresh di tengah muat lanjutan) dibuang.
  int _reqId = 0;

  PagedListNotifier(this._fetch, {this.pageLimit = defaultPageLimit})
    : super(PagedListState<T>()) {
    _load(reset: true);
  }

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore || state.error != null) return;
    await _load();
  }

  Future<void> refresh() => _load(reset: true);

  /// Mengulang permintaan yang gagal (halaman pertama atau lanjutan).
  Future<void> retry() => _load(reset: state.items.isEmpty);

  Future<void> _load({bool reset = false}) async {
    final req = ++_reqId;
    final page = reset ? 1 : state.nextPage;
    state = PagedListState<T>(
      items: reset ? const [] : state.items,
      total: reset ? 0 : state.total,
      loading: true,
      hasMore: true,
      nextPage: page,
    );

    try {
      final result = await _fetch(page, pageLimit);
      if (!mounted || req != _reqId) return;
      state = PagedListState<T>(
        items: [...state.items, ...result.items],
        total: result.total,
        hasMore: result.hasMore,
        nextPage: page + 1,
      );
    } catch (e) {
      if (!mounted || req != _reqId) return;
      state = PagedListState<T>(
        items: state.items,
        total: state.total,
        hasMore: state.hasMore,
        nextPage: page,
        error: e,
      );
    }
  }
}
