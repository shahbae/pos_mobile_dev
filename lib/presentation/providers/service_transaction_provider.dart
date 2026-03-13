import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/customer_model.dart';
import 'package:pos_mobile/data/models/service_model.dart';
import 'package:pos_mobile/data/models/service_transaction_model.dart';
import 'package:pos_mobile/data/repositories/service_transaction_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';

class ServiceTransactionState {
  final Map<ServiceModel, double> cart; // Using double for quantity as it can be decimal
  final Customer? selectedCustomer;
  final String paymentMethod;
  final double paidAmount;
  final bool isLoading;
  final String? error;

  ServiceTransactionState({
    this.cart = const {},
    this.selectedCustomer,
    this.paymentMethod = 'cash',
    this.paidAmount = 0,
    this.isLoading = false,
    this.error,
  });

  ServiceTransactionState copyWith({
    Map<ServiceModel, double>? cart,
    Customer? selectedCustomer,
    String? paymentMethod,
    double? paidAmount,
    bool? isLoading,
    String? error,
  }) {
    return ServiceTransactionState(
      cart: cart ?? this.cart,
      selectedCustomer: selectedCustomer ?? this.selectedCustomer,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidAmount: paidAmount ?? this.paidAmount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  double get totalPrice {
    double total = 0;
    cart.forEach((service, quantity) {
      total += (service.priceNum * quantity);
    });
    return total;
  }
}

final serviceTransactionRepositoryProvider = Provider<ServiceTransactionRepository>((ref) {
  final api = ref.watch(apiProvider);
  return ServiceTransactionRepository(api);
});

final serviceTransactionProvider = StateNotifierProvider<ServiceTransactionNotifier, ServiceTransactionState>((ref) {
  final repo = ref.watch(serviceTransactionRepositoryProvider);
  return ServiceTransactionNotifier(repo);
});

class ServiceTransactionNotifier extends StateNotifier<ServiceTransactionState> {
  final ServiceTransactionRepository repo;

  ServiceTransactionNotifier(this.repo) : super(ServiceTransactionState());

  void setCustomer(Customer? customer) {
    state = state.copyWith(selectedCustomer: customer);
  }

  void addToCart(ServiceModel service, double quantity) {
    final newCart = Map<ServiceModel, double>.from(state.cart);
    if (newCart.containsKey(service)) {
      newCart[service] = newCart[service]! + quantity;
    } else {
      newCart[service] = quantity;
    }
    state = state.copyWith(cart: newCart);
  }

  void updateQuantity(ServiceModel service, double quantity) {
    final newCart = Map<ServiceModel, double>.from(state.cart);
    if (quantity <= 0) {
      newCart.remove(service);
    } else {
      newCart[service] = quantity;
    }
    state = state.copyWith(cart: newCart);
  }

  void removeFromCart(ServiceModel service) {
    final newCart = Map<ServiceModel, double>.from(state.cart);
    newCart.remove(service);
    state = state.copyWith(cart: newCart);
  }

  void clearCart() {
    state = ServiceTransactionState();
  }

  void updatePayment(String method, double amount) {
    state = state.copyWith(paymentMethod: method, paidAmount: amount);
  }

  Future<ServiceTransactionResponse> checkout() async {
    if (state.cart.isEmpty) throw 'Keranjang kosong';
    if (state.paidAmount < state.totalPrice) {
      throw 'Nominal pembayaran kurang dari total tagihan';
    }

    state = state.copyWith(isLoading: true, error: null);

    final items = state.cart.entries.map((e) {
      // Format quantity cleanly, dropping .0 if it's an integer
      String qStr = e.value.toString();
      if (qStr.endsWith('.0')) {
        qStr = qStr.substring(0, qStr.length - 2);
      }
      return ServiceTransactionItem(
        serviceId: e.key.id,
        quantity: qStr,
      );
    }).toList();

    final req = ServiceTransactionRequest(
      items: items,
      paymentMethod: state.paymentMethod,
      paidAmount: state.paidAmount.toInt().toString(),
      customerId: state.selectedCustomer?.id,
    );

    try {
      final res = await repo.checkout(req);
      state = state.copyWith(isLoading: false);
      
      // Clear cart after success
      clearCart();
      return res;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}
