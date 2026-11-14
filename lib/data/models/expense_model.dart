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

  /// ACC SPV (revisi KPI 11 Nov, SPV-A7): `approved` / `pending` /
  /// `rejected`. Yang menunggu atau ditolak tidak dihitung sebagai
  /// pengeluaran; yang ditolak harus dikembalikan ke laci.
  final String approvalStatus;
  final String approvalNote;

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
    this.approvalStatus = 'approved',
    this.approvalNote = '',
  });

  bool get isPendingApproval => approvalStatus == 'pending';
  bool get isRejected => approvalStatus == 'rejected';

  /// Label status ACC untuk daftar & detail; kosong bila sudah disetujui.
  String get approvalLabel => isPendingApproval ? 'Menunggu ACC SPV' : (isRejected ? 'Ditolak SPV' : '');

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
      approvalStatus: (j['approval_status']?.toString().isNotEmpty ?? false) ? j['approval_status'].toString() : 'approved',
      approvalNote: j['approval_note']?.toString() ?? '',
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

  /// Standar harian per outlet (Tahap 7). Total jenis ini sehari di outlet
  /// yang melewatinya menunggu ACC SPV (revisi KPI 11 Nov). Null = tanpa
  /// standar.
  final double? dailyStandard;

  const CostType({
    required this.id,
    required this.name,
    this.isOpex = false,
    this.isActive = true,
    this.sort = 0,
    this.dailyStandard,
  });

  factory CostType.fromJson(Map<String, dynamic> j) => CostType(
    id: j['id'] is num ? (j['id'] as num).toInt() : int.tryParse('${j['id']}') ?? 0,
    name: '${j['name'] ?? ''}',
    isOpex: j['is_opex'] == true,
    isActive: j['is_active'] != false,
    sort: j['sort'] is num ? (j['sort'] as num).toInt() : 0,
    dailyStandard: j['daily_standard'] == null ? null : double.tryParse('${j['daily_standard']}'),
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

/// Status ACC dari jawaban `POST/PUT /expenses` (`{data: {...}}`).
String expenseApprovalOf(Map<String, dynamic>? res) {
  final d = res?['data'];
  return d is Map ? (d['approval_status']?.toString() ?? '') : '';
}
