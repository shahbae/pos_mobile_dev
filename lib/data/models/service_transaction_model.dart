import 'package:flutter/foundation.dart';

class ServiceTransactionRequest {
  final List<ServiceTransactionItem> items;
  final String paymentMethod;
  final String paidAmount;
  final int? customerId;

  ServiceTransactionRequest({
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

class ServiceTransactionItem {
  final int serviceId;
  final String quantity; // Using string to allow decimals like "2.5"

  ServiceTransactionItem({
    required this.serviceId,
    required this.quantity,
  });

  Map<String, dynamic> toJson() {
    return {
      'service_id': serviceId,
      'quantity': quantity,
    };
  }
}

class ServiceTransactionResponse {
  final String invoiceNumber;
  final int saleId;
  final bool success;

  ServiceTransactionResponse({
    required this.invoiceNumber,
    required this.saleId,
    required this.success,
  });

  factory ServiceTransactionResponse.fromJson(Map<String, dynamic> json) {
    debugPrint('[ServiceTransactionModel] Parsing JSON: $json');
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
    debugPrint('[ServiceTransactionModel] Extracted invoice: $invoice');
    
    return ServiceTransactionResponse(
      invoiceNumber: invoice.toString(),
      saleId: data['sale_id'] ?? json['sale_id'] ?? 0,
      success: json['success'] ?? false,
    );
  }
}
