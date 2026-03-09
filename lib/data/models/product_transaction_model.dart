import 'package:flutter/foundation.dart';

class ProductTransactionRequest {
  final List<TransactionItem> items;
  final String paymentMethod;
  final String paidAmount;
  final int? customerId;

  ProductTransactionRequest({
    required this.items,
    required this.paymentMethod,
    required this.paidAmount,
    this.customerId,
  });

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((i) => i.toJson()).toList(),
      'payment_method': paymentMethod,
      'paid_amount': paidAmount,
      if (customerId != null) 'customer_id': customerId,
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
      'quantity': quantity,
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
