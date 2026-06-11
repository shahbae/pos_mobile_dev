import 'package:flutter/foundation.dart';

/// Pilihan topping pada sebuah item (gratis maupun berbayar).
class ToppingSelection {
  final int toppingId;
  final int qty;

  ToppingSelection({required this.toppingId, required this.qty});

  Map<String, dynamic> toJson() => {
        'topping_id': toppingId,
        'qty': qty,
      };
}

class ProductTransactionRequest {
  final List<TransactionItem> items;
  final List<PromoFreeItem> promoFreeItems;
  final String paymentMethod; // CASH | TRANSFER | QRIS | DEBIT | CREDIT | EWALLET
  final int paid; // integer rupiah
  final int discount; // integer rupiah
  final String? paymentRef; // nomor referensi untuk non-cash
  final String? customerName; // atas nama (free text), opsional
  final String? idempotencyKey;

  ProductTransactionRequest({
    required this.items,
    this.promoFreeItems = const [],
    required this.paymentMethod,
    required this.paid,
    this.discount = 0,
    this.paymentRef,
    this.customerName,
    this.idempotencyKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'payment_method': paymentMethod,
      'payment_ref': paymentRef,
      'paid': paid,
      'discount': discount,
      'items': items.map((i) => i.toJson()).toList(),
      if (promoFreeItems.isNotEmpty)
        'promo_free_items': promoFreeItems.map((p) => p.toJson()).toList(),
      if (customerName != null && customerName!.isNotEmpty) 'customer_name': customerName,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    };
  }
}

class TransactionItem {
  final int productId;
  final int quantity;
  final List<ToppingSelection> freeToppings; // include di harga, tidak menambah subtotal
  final List<ToppingSelection> extraToppings; // berbayar

  TransactionItem({
    required this.productId,
    required this.quantity,
    this.freeToppings = const [],
    this.extraToppings = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'qty': quantity,
      if (freeToppings.isNotEmpty)
        'free_toppings': freeToppings.map((t) => t.toJson()).toList(),
      if (extraToppings.isNotEmpty)
        'extra_toppings': extraToppings.map((t) => t.toJson()).toList(),
    };
  }
}

/// Item yang digratiskan lewat promo. Kasir menentukan item mana yang gratis.
class PromoFreeItem {
  final int promoId;
  final int productId;
  final int qty;
  final List<ToppingSelection> extraToppings; // extra topping pada item gratis (tetap ditagih)

  PromoFreeItem({
    required this.promoId,
    required this.productId,
    required this.qty,
    this.extraToppings = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'promo_id': promoId,
      'product_id': productId,
      'qty': qty,
      if (extraToppings.isNotEmpty)
        'extra_toppings': extraToppings.map((t) => t.toJson()).toList(),
    };
  }
}

class ProductTransactionResponse {
  final String invoiceNumber;
  final int saleId;
  final bool success;

  ProductTransactionResponse({
    required this.invoiceNumber,
    required this.saleId,
    required this.success,
  });

  factory ProductTransactionResponse.fromJson(Map<String, dynamic> json) {
    debugPrint('[TransactionModel] Parsing JSON: $json');
    final data = json['data'] ?? json; // Fallback to root if data is missing
    final invoice = data['invoice_number'] ??
        data['invoice_no'] ??
        data['invoiceNumber'] ??
        data['invoiceNo'] ??
        data['invoice'] ??
        data['ref'] ??
        json['invoice_number'] ??
        json['invoice_no'] ??
        json['invoiceNumber'] ??
        json['invoiceNo'] ??
        json['invoice'] ??
        json['ref'] ??
        '';
    debugPrint('[TransactionModel] Extracted invoice: $invoice');

    return ProductTransactionResponse(
      invoiceNumber: invoice.toString(),
      saleId: data['sale_id'] ?? json['sale_id'] ?? 0,
      success: json['success'] ?? false,
    );
  }
}
