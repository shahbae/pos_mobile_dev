class ExpenseModel {
  final int? id;
  final int? tenantId;
  final String? amount;
  final String? category;
  final String? description;
  final String? expenseDate;
  final int? createdBy;
  final String? createdAt;

  /// URL penuh foto bukti (siap dipakai di Image.network). Bisa `null` untuk
  /// data lama sebelum fitur foto wajib (revisi BE 2026-07-07).
  final String? photoUrl;

  ExpenseModel({
    this.id,
    this.tenantId,
    this.amount,
    this.category,
    this.description,
    this.expenseDate,
    this.createdBy,
    this.createdAt,
    this.photoUrl,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> j) {
    return ExpenseModel(
      id: j['id'],
      tenantId: j['tenant_id'],
      amount: j['amount']?.toString(),
      category: j['category'],
      description: j['description'],
      expenseDate: j['expense_date'],
      createdBy: j['created_by'],
      createdAt: j['created_at'],
      photoUrl: (j['photo_url']?.toString().isEmpty ?? true)
          ? null
          : j['photo_url'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'category': category,
      'description': description,
      'expense_date': expenseDate,
    };
  }
}
