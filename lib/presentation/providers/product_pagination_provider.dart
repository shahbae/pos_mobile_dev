import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/repositories/product_repository.dart';
import 'package:pos_mobile/presentation/providers/product_provider.dart';
import 'package:pos_mobile/data/models/product_model.dart';

/// Tab kategori untuk filter menu POS.
class ProductCategoryTab {
  final int id;
  final String name;
  const ProductCategoryTab(this.id, this.name);
}

class ProductPaginationState {
  /// Seluruh katalog (dimuat sekali). Filter search & kategori dilakukan di klien.
  final List<Product> allItems;
  final bool loading;
  final String search;

  /// null = tab "Semua".
  final int? categoryId;

  /// Pesan error muat katalog; null bila muat terakhir berhasil.
  final String? error;

  ProductPaginationState({
    this.allItems = const [],
    this.loading = false,
    this.search = "",
    this.categoryId,
    this.error,
  });

  ProductPaginationState copyWith({
    List<Product>? allItems,
    bool? loading,
    String? search,
    int? categoryId,
    bool clearCategory = false,
    String? error,
    bool clearError = false,
  }) {
    return ProductPaginationState(
      allItems: allItems ?? this.allItems,
      loading: loading ?? this.loading,
      search: search ?? this.search,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Produk setelah difilter kategori + pencarian nama.
  List<Product> get items {
    final q = search.trim().toLowerCase();
    return allItems.where((p) {
      final matchCat = categoryId == null || p.categoryId == categoryId;
      final matchSearch = q.isEmpty || p.name.toLowerCase().contains(q);
      return matchCat && matchSearch;
    }).toList();
  }

  /// Daftar kategori unik (urut sesuai kemunculan di katalog).
  List<ProductCategoryTab> get categories {
    final seen = <int>{};
    final out = <ProductCategoryTab>[];
    for (final p in allItems) {
      final id = p.categoryId;
      final name = p.categoryName;
      if (id != null && name != null && name.isNotEmpty && seen.add(id)) {
        out.add(ProductCategoryTab(id, name));
      }
    }
    return out;
  }
}

final productPaginationProvider =
    StateNotifierProvider.autoDispose<ProductPaginationNotifier, ProductPaginationState>((
      ref,
    ) {
      final repo = ref.watch(productRepositoryProvider);
      return ProductPaginationNotifier(repo)..loadAll();
    });

class ProductPaginationNotifier extends StateNotifier<ProductPaginationState> {
  final ProductRepository repo;
  Timer? _debounce;

  ProductPaginationNotifier(this.repo) : super(ProductPaginationState());

  /// Muat seluruh katalog (looping semua halaman). Menu POS biasanya kecil,
  /// jadi cukup sekali muat lalu filter kategori/search di klien.
  ///
  /// `loading` WAJIB dikembalikan ke false di jalur gagal juga: kalau satu
  /// halaman error (jaringan goyang saat ramai) dan flag-nya tertinggal `true`,
  /// semua panggilan berikutnya ikut ter-skip oleh guard di bawah dan katalog
  /// beku permanen — kasir cuma lihat stok lama tanpa cara memulihkan.
  Future<void> loadAll() async {
    if (state.loading) return;
    state = state.copyWith(loading: true, clearError: true);

    const pageSize = 50;
    final all = <Product>[];
    var page = 1;
    try {
      while (page <= 100) {
        final res = await repo.getProducts(page: page, limit: pageSize);
        all.addAll(res);
        if (res.length < pageSize) break;
        page++;
      }
      // Notifier bisa sudah di-dispose saat request selesai (kasir pindah halaman).
      if (!mounted) return;
      state = state.copyWith(allItems: all, loading: false, clearError: true);
    } catch (e) {
      if (!mounted) return;
      // Katalog lama dipertahankan supaya kasir tetap bisa jualan; error
      // ditampilkan agar jelas datanya belum tentu terbaru.
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      state = state.copyWith(search: value);
    });
  }

  /// id null = tab "Semua".
  void selectCategory(int? id) {
    state = state.copyWith(categoryId: id, clearCategory: id == null);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
