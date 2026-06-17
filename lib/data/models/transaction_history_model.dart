/// Item jurnal transaksi terpadu (GET /transactions).
/// Mencakup tipe: pos | purchase | expense.
class TransactionHistoryModel {
  final String transactionType; // pos | purchase | expense
  final int id;
  final int? branchId;
  final String? branchName;
  final String amount; // string desimal "0.00"
  final String txnDate; // ISO 8601 (mis. 2026-06-17T10:30:00+07:00)
  final String? ref; // invoice/PO number (POS & purchase)
  final String? paymentMethod; // hanya pos
  final int? supplierId; // hanya purchase
  final String? supplierName; // hanya purchase
  final String? category; // hanya expense
  final String? note;
  final String? actorName; // user pelaku transaksi

  TransactionHistoryModel({
    required this.transactionType,
    required this.id,
    this.branchId,
    this.branchName,
    required this.amount,
    required this.txnDate,
    this.ref,
    this.paymentMethod,
    this.supplierId,
    this.supplierName,
    this.category,
    this.note,
    this.actorName,
  });

  double get amountNum => double.tryParse(amount) ?? 0;
  bool get isPurchase => transactionType == 'purchase';
  bool get isExpense => transactionType == 'expense';
  bool get isPos => transactionType == 'pos';

  /// Nomor referensi siap tampil (kosong bila null).
  String get refOrEmpty => ref ?? '';

  factory TransactionHistoryModel.fromJson(Map<String, dynamic> json) {
    // Catatan: response server saat ini memakai `invoice_number` & `created_at`
    // (nama lama), sedangkan dokumen BE menyebut `ref` & `txn_date`. Baca
    // keduanya (fallback) agar tetap jalan apa pun yang dikirim server.
    return TransactionHistoryModel(
      transactionType: json['transaction_type']?.toString() ?? '',
      id: (json['id'] as num?)?.toInt() ?? 0,
      branchId: (json['branch_id'] as num?)?.toInt(),
      branchName: json['branch_name']?.toString(),
      amount: (json['amount'] ?? json['total_amount'])?.toString() ?? '0',
      txnDate: (json['txn_date'] ?? json['created_at'])?.toString() ?? '',
      ref: (json['ref'] ?? json['invoice_number'])?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      supplierId: (json['supplier_id'] as num?)?.toInt(),
      supplierName: json['supplier_name']?.toString(),
      category: json['category']?.toString(),
      note: json['note']?.toString(),
      actorName: json['actor_name']?.toString(),
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
      id: (json['id'] as num?)?.toInt() ?? 0,
      transactionId: (json['transaction_id'] as num?)?.toInt() ?? 0,
      paymentMethod: json['payment_method']?.toString() ?? '',
      // amount bisa dikirim sbg angka ATAU string → selalu toString() agar aman.
      amountPaid: json['amount_paid']?.toString() ?? '0',
      changeAmount: json['change_amount']?.toString() ?? '0',
      paymentStatus: json['payment_status']?.toString() ?? '',
      paidAt: json['paid_at']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
