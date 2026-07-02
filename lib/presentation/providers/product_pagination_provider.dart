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

  ProductPaginationState({
    this.allItems = const [],
    this.loading = false,
    this.search = "",
    this.categoryId,
  });

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
  Future<void> loadAll() async {
    if (state.loading) return;
    state = ProductPaginationState(
      allItems: state.allItems,
      loading: true,
      search: state.search,
      categoryId: state.categoryId,
    );

    const pageSize = 50;
    final all = <Product>[];
    var page = 1;
    while (page <= 100) {
      final res = await repo.getProducts(page: page, limit: pageSize);
      all.addAll(res);
      if (res.length < pageSize) break;
      page++;
    }

    state = ProductPaginationState(
      allItems: all,
      loading: false,
      search: state.search,
      categoryId: state.categoryId,
    );
  }

  void search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      state = ProductPaginationState(
        allItems: state.allItems,
        loading: state.loading,
        search: value,
        categoryId: state.categoryId,
      );
    });
  }

  void selectCategory(int? id) {
    state = ProductPaginationState(
      allItems: state.allItems,
      loading: state.loading,
      search: state.search,
      categoryId: id,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
