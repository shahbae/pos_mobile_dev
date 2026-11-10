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

  /// Jenis Biaya (Tahap 7, SPV-A7 & F-1.3). Kosong untuk data lama; tanpa
  /// jenis, pengeluaran tidak ikut dihitung KPI.
  final int? costTypeId;

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
    this.costTypeId,
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
      costTypeId: j['cost_type_id'] is num ? (j['cost_type_id'] as num).toInt() : int.tryParse('${j['cost_type_id'] ?? ''}'),
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

/// Jenis Biaya (`GET /cost-types`). Daftarnya milik owner/finance di web.
class CostType {
  final int id;
  final String name;
  final bool isOpex;
  final bool isActive;
  final int sort;

  const CostType({required this.id, required this.name, this.isOpex = false, this.isActive = true, this.sort = 0});

  factory CostType.fromJson(Map<String, dynamic> j) => CostType(
    id: j['id'] is num ? (j['id'] as num).toInt() : int.tryParse('${j['id']}') ?? 0,
    name: '${j['name'] ?? ''}',
    isOpex: j['is_opex'] == true,
    isActive: j['is_active'] != false,
    sort: j['sort'] is num ? (j['sort'] as num).toInt() : 0,
  );
}

/// Nama jenis biaya dari daftar, atau null bila tidak dikenal.
String? costTypeName(List<CostType> types, int? id) {
  if (id == null) return null;
  for (final t in types) {
    if (t.id == id) return t.name;
  }
  return null;
}
