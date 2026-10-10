import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/product_model.dart';
import 'package:pos_mobile/presentation/providers/pos_catalog_provider.dart';

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
      // Menonton notifier-nya menjaga katalog tetap hidup selama daftar produk
      // dipakai, dan membuat daftar ini lahir ulang saat kasir pindah cabang.
      final catalog = ref.watch(posCatalogProvider.notifier);
      final notifier = ProductPaginationNotifier(catalog.refresh);
      ref.listen<PosCatalogState>(
        posCatalogProvider,
        (_, next) => notifier.applyCatalog(next),
        fireImmediately: true,
      );
      return notifier;
    });

class ProductPaginationNotifier extends StateNotifier<ProductPaginationState> {
  final Future<void> Function() _refreshCatalog;
  Timer? _debounce;

  ProductPaginationNotifier(this._refreshCatalog) : super(ProductPaginationState());

  /// Minta katalog diperbarui dari server. Daftar produk sendiri datang dari
  /// katalog lewat [applyCatalog]; pencarian dan tab kategori tetap di klien.
  Future<void> loadAll() => _refreshCatalog();

  /// Ikuti keadaan katalog. Daftar lama dipertahankan selama katalog belum
  /// punya isi, supaya kasir tetap bisa jualan saat pembaruan gagal; galatnya
  /// ditampilkan agar jelas datanya belum tentu terbaru.
  void applyCatalog(PosCatalogState catalog) {
    final items = catalog.catalog?.products ?? state.allItems;
    if (identical(items, state.allItems) &&
        catalog.refreshing == state.loading &&
        catalog.error == state.error) {
      return;
    }
    state = state.copyWith(
      allItems: items,
      loading: catalog.refreshing,
      error: catalog.error,
      clearError: catalog.error == null,
    );
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
