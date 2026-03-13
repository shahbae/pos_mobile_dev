class TransactionHistoryModel {
  final int id;
  final String transactionType;
  final String totalAmount;
  final String createdAt;
  final String invoiceNumber;
  final String paymentMethod;
  final String status;

  TransactionHistoryModel({
    required this.id,
    required this.transactionType,
    required this.totalAmount,
    required this.createdAt,
    required this.invoiceNumber,
    required this.paymentMethod,
    required this.status,
  });

  double get totalAmountNum => double.tryParse(totalAmount) ?? 0;

  factory TransactionHistoryModel.fromJson(Map<String, dynamic> json) {
    return TransactionHistoryModel(
      id: json['id'] ?? 0,
      transactionType: json['transaction_type'] ?? '',
      totalAmount: json['total_amount'] ?? '0',
      createdAt: json['created_at'] ?? '',
      invoiceNumber: json['invoice_number'] ?? '',
      paymentMethod: json['payment_method'] ?? '',
      status: json['status'] ?? '',
    );
  }
}

class TransactionHistoryResponse {
  final List<TransactionHistoryModel> items;
  final int total;
  final int page;
  final int limit;

  TransactionHistoryResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory TransactionHistoryResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    final List<dynamic> itemsJson = data['items'] ?? [];
    
    return TransactionHistoryResponse(
      items: itemsJson.map((i) => TransactionHistoryModel.fromJson(i)).toList(),
      total: data['total'] ?? 0,
      page: data['page'] ?? 1,
      limit: data['limit'] ?? 20,
    );
  }
}

class PaymentModel {
  final int id;
  final int transactionId;
  final String paymentMethod;
  final String amountPaid;
  final String changeAmount;
  final String paymentStatus;
  final String paidAt;
  final String createdAt;

  PaymentModel({
    required this.id,
    required this.transactionId,
    required this.paymentMethod,
    required this.amountPaid,
    required this.changeAmount,
    required this.paymentStatus,
    required this.paidAt,
    required this.createdAt,
  });

  double get amountPaidNum => double.tryParse(amountPaid) ?? 0;
  double get changeAmountNum => double.tryParse(changeAmount) ?? 0;

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] ?? 0,
      transactionId: json['transaction_id'] ?? 0,
      paymentMethod: json['payment_method'] ?? '',
      amountPaid: json['amount_paid'] ?? '0',
      changeAmount: json['change_amount'] ?? '0',
      paymentStatus: json['payment_status'] ?? '',
      paidAt: json['paid_at'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}
