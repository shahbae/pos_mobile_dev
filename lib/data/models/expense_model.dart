class ExpenseModel {
  final int? id;
  final int? tenantId;
  final String? amount;
  final String? category;
  final String? description;
  final String? expenseDate;
  final int? createdBy;
  final String? createdAt;

  ExpenseModel({
    this.id,
    this.tenantId,
    this.amount,
    this.category,
    this.description,
    this.expenseDate,
    this.createdBy,
    this.createdAt,
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
