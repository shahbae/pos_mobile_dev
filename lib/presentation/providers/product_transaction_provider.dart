import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/product_model.dart';
import 'package:pos_mobile/data/models/product_transaction_model.dart';
import 'package:pos_mobile/data/repositories/product_transaction_repository.dart';

class CartItem {
  final Product product;
  final int quantity;

  CartItem({required this.product, required this.quantity});

  CartItem copyWith({int? quantity}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
    );
  }

  double get subtotal => (product.sellingPriceNum * quantity).toDouble();
}

class ProductTransactionState {
  final List<CartItem> items;
  final bool isLoading;
  final String? error;
  final ProductTransactionResponse? lastResponse;

  ProductTransactionState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.lastResponse,
  });

  double get total => items.fold(0, (sum, item) => sum + item.subtotal);

  ProductTransactionState copyWith({
    List<CartItem>? items,
    bool? isLoading,
    String? error,
    ProductTransactionResponse? lastResponse,
  }) {
    return ProductTransactionState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastResponse: lastResponse ?? this.lastResponse,
    );
  }
}

final productTransactionProvider =
    StateNotifierProvider.autoDispose<ProductTransactionNotifier, ProductTransactionState>((ref) {
  final repo = ref.watch(productTransactionRepositoryProvider);
  return ProductTransactionNotifier(repo);
});

class ProductTransactionNotifier extends StateNotifier<ProductTransactionState> {
  final ProductTransactionRepository repo;

  ProductTransactionNotifier(this.repo) : super(ProductTransactionState());

  void addToCart(Product product) {
    final existingIndex = state.items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex != -1) {
      final updatedItems = List<CartItem>.from(state.items);
      updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
        quantity: updatedItems[existingIndex].quantity + 1,
      );
      state = state.copyWith(items: updatedItems);
    } else {
      state = state.copyWith(
        items: [...state.items, CartItem(product: product, quantity: 1)],
      );
    }
  }

  void removeFromCart(int productId) {
    state = state.copyWith(
      items: state.items.where((item) => item.product.id != productId).toList(),
    );
  }

  void updateQuantity(int productId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }

    final updatedItems = state.items.map((item) {
      if (item.product.id == productId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
  }

  void clearCart() {
    state = state.copyWith(items: [], lastResponse: null, error: null);
  }

  Future<void> submitTransaction({
    required String paymentMethod,
    required int paid,
    int discount = 0,
    String? paymentRef,
    String? customerName,
  }) async {
    if (state.items.isEmpty) return;

    state = state.copyWith(isLoading: true, error: null);

    final request = ProductTransactionRequest(
      items: state.items
          .map((item) => TransactionItem(
                productId: item.product.id,
                quantity: item.quantity,
              ))
          .toList(),
      paymentMethod: paymentMethod,
      paid: paid,
      discount: discount,
      paymentRef: paymentRef,
      customerName: customerName,
      idempotencyKey: _genIdempotencyKey(),
    );

    try {
      final response = await repo.createTransaction(request);
      state = state.copyWith(
        isLoading: false,
        lastResponse: response,
        items: [], // Clear cart on success
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Idempotency key unik per submit (cegah transaksi dobel saat retry).
  String _genIdempotencyKey() {
    final rnd = Random();
    String seg(int n) =>
        List.generate(n, (_) => rnd.nextInt(16).toRadixString(16)).join();
    return '${seg(8)}-${seg(4)}-4${seg(3)}-${seg(4)}-${seg(12)}';
  }
}
