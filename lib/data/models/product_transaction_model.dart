import 'package:flutter/foundation.dart';

class ProductTransactionRequest {
  final List<TransactionItem> items;
  final String paymentMethod; // CASH | TRANSFER | QRIS | DEBIT | CREDIT | EWALLET
  final int paid; // integer rupiah
  final int discount; // integer rupiah
  final String? paymentRef; // nomor referensi untuk non-cash
  final String? customerName; // atas nama (free text), opsional
  final String? idempotencyKey;

  ProductTransactionRequest({
    required this.items,
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
      if (customerName != null && customerName!.isNotEmpty) 'customer_name': customerName,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    };
  }
}

class TransactionItem {
  final int productId;
  final int quantity;

  TransactionItem({
    required this.productId,
    required this.quantity,
  });

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'qty': quantity,
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
