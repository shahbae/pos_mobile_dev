import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/repositories/product_repository.dart';
import 'package:pos_mobile/presentation/providers/product_provider.dart';
import 'package:pos_mobile/data/models/product_model.dart';

class ProductPaginationState {
  final List<Product> items;
  final bool loading;
  final bool hasMore;
  final int page;
  final String search;

  ProductPaginationState({
    this.items = const [],
    this.loading = false,
    this.hasMore = true,
    this.page = 1,
    this.search = "",
  });

  ProductPaginationState copyWith({
    List<Product>? items,
    bool? loading,
    bool? hasMore,
    int? page,
    String? search,
  }) {
    return ProductPaginationState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      search: search ?? this.search,
    );
  }
}

final productPaginationProvider =
    StateNotifierProvider.autoDispose<ProductPaginationNotifier, ProductPaginationState>((
      ref,
    ) {
      final repo = ref.watch(productRepositoryProvider);
      return ProductPaginationNotifier(repo)..load(reset: true);
    });

class ProductPaginationNotifier extends StateNotifier<ProductPaginationState> {
  final ProductRepository repo;
  Timer? _debounce;

  ProductPaginationNotifier(this.repo) : super(ProductPaginationState());

  Future<void> load({bool reset = false}) async {
    if (state.loading || (!state.hasMore && !reset)) return;

    final page = reset ? 1 : state.page;
    state = state.copyWith(loading: true);

    final result = await repo.getProducts(
      page: page,
      limit: 10,
      search: state.search.isEmpty ? null : state.search,
    );

    state = state.copyWith(
      items: reset ? result : [...state.items, ...result],
      loading: false,
      hasMore: result.length == 10,
      page: page + 1,
    );
  }

  void search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      state = state.copyWith(search: value);
      load(reset: true);
    });
  }
}
