import '../../../data/models/product_model.dart';

class ProductListState {
  final List<Product> items;
  final bool loading;
  final bool hasMore;
  final int page;
  final String search;

  ProductListState({
    this.items = const [],
    this.loading = false,
    this.hasMore = true,
    this.page = 1,
    this.search = "",
  });

  ProductListState copyWith({
    List<Product>? items,
    bool? loading,
    bool? hasMore,
    int? page,
    String? search,
  }) {
    return ProductListState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      search: search ?? this.search,
    );
  }
}
