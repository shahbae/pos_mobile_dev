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

  /// Pemutus ACC. Kosong pada pengeluaran yang disetujui = lolos sendiri
  /// (di bawah batas saat dicatat, atau dinilai ulang otomatis).
  final int? approvalDecidedBy;

  /// Batas pengeluaran persen omzet (revisi 19 Nov): grup `A` (harian) / `B`
  /// (bulanan), akumulasi grup termasuk baris ini, dan batas rupiahnya saat
  /// dinilai. Kosong untuk data lama.
  final String limitGroup;
  final double? limitAccum;
  final double? limitPagu;

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
    this.approvalDecidedBy,
    this.limitGroup = '',
    this.limitAccum,
    this.limitPagu,
  });

  bool get isPendingApproval => approvalStatus == 'pending';
  bool get isRejected => approvalStatus == 'rejected';

  /// Sempat menunggu lalu lolos sendiri saat dinilai ulang (bukan diputus SPV).
  bool get isAutoApproved =>
      approvalStatus == 'approved' && approvalDecidedBy == null && approvalNote.startsWith('Lolos otomatis');

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
      approvalDecidedBy: j['approval_decided_by'] is num ? (j['approval_decided_by'] as num).toInt() : null,
      limitGroup: j['limit_group']?.toString() ?? '',
      limitAccum: _toDouble(j['limit_accum']),
      limitPagu: _toDouble(j['limit_pagu']),
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

double? _toDouble(Object? v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

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

  /// Grup batas pengeluaran (revisi 19 Nov): `A` = es kristal & air galon,
  /// batas harian; `B` = lainnya, batas bulanan.
  final String expenseGroup;

  bool get isDailyGroup => expenseGroup == expenseGroupDaily;

  const CostType({
    required this.id,
    required this.name,
    this.isOpex = false,
    this.isActive = true,
    this.sort = 0,
    this.dailyStandard,
    this.expenseGroup = expenseGroupMonthly,
  });

  factory CostType.fromJson(Map<String, dynamic> j) => CostType(
    id: j['id'] is num ? (j['id'] as num).toInt() : int.tryParse('${j['id']}') ?? 0,
    name: '${j['name'] ?? ''}',
    isOpex: j['is_opex'] == true,
    isActive: j['is_active'] != false,
    sort: j['sort'] is num ? (j['sort'] as num).toInt() : 0,
    dailyStandard: j['daily_standard'] == null ? null : double.tryParse('${j['daily_standard']}'),
    expenseGroup: '${j['expense_group'] ?? ''}' == expenseGroupDaily ? expenseGroupDaily : expenseGroupMonthly,
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

const expenseGroupDaily = 'A';
const expenseGroupMonthly = 'B';

/// Pratinjau batas pengeluaran outlet hari ini (`GET /expense-limits`,
/// revisi 19 Nov). Grup A: total hari ini ≤ [dailyPct]% omzet hari ini.
/// Grup B: total bulan ini ≤ [monthlyPct]% omzet bulan berjalan / target.
class ExpenseLimitPreview {
  final double dailyPct;
  final double monthlyPct;
  final String monthlyBasis;
  final double dailyOmzet;
  final double dailyPagu;
  final double todayGroupA;
  final double monthBase;
  final double monthlyPagu;
  final double monthGroupB;
  final int cutoffHour;

  const ExpenseLimitPreview({
    this.dailyPct = 9,
    this.monthlyPct = 0.8,
    this.monthlyBasis = 'mtd',
    this.dailyOmzet = 0,
    this.dailyPagu = 0,
    this.todayGroupA = 0,
    this.monthBase = 0,
    this.monthlyPagu = 0,
    this.monthGroupB = 0,
    this.cutoffHour = 21,
  });

  factory ExpenseLimitPreview.fromJson(Map<String, dynamic> j) {
    final setting = j['setting'] is Map ? Map<String, dynamic>.from(j['setting']) : const <String, dynamic>{};
    final p = j['preview'] is Map ? Map<String, dynamic>.from(j['preview']) : const <String, dynamic>{};
    return ExpenseLimitPreview(
      dailyPct: _toDouble(setting['daily_pct']) ?? 9,
      monthlyPct: _toDouble(setting['monthly_pct']) ?? 0.8,
      monthlyBasis: '${p['monthly_basis'] ?? setting['monthly_basis'] ?? 'mtd'}',
      dailyOmzet: _toDouble(p['daily_omzet']) ?? 0,
      dailyPagu: _toDouble(p['daily_pagu']) ?? 0,
      todayGroupA: _toDouble(p['today_group_a']) ?? 0,
      monthBase: _toDouble(p['month_base']) ?? 0,
      monthlyPagu: _toDouble(p['monthly_pagu']) ?? 0,
      monthGroupB: _toDouble(p['month_group_b']) ?? 0,
      cutoffHour: p['cutoff_hour'] is num ? (p['cutoff_hour'] as num).toInt() : 21,
    );
  }

  /// Perkiraan status pengeluaran baru sebesar [amount] di [group].
  /// [replacing] = nominal lama baris yang sedang diubah (sudah ikut dihitung
  /// server), supaya tidak terhitung dua kali.
  ExpenseLimitProjection project(String group, double amount, {double replacing = 0}) {
    final daily = group == expenseGroupDaily;
    final used = (daily ? todayGroupA : monthGroupB) - replacing;
    final pagu = daily ? dailyPagu : monthlyPagu;
    return ExpenseLimitProjection(
      group: daily ? expenseGroupDaily : expenseGroupMonthly,
      used: used < 0 ? 0 : used,
      accum: (used < 0 ? 0 : used) + amount,
      pagu: pagu,
    );
  }
}

class ExpenseLimitProjection {
  final String group;
  final double used;
  final double accum;
  final double pagu;

  const ExpenseLimitProjection({required this.group, required this.used, required this.accum, required this.pagu});

  /// Sama dengan aturan server: lewat batas bila akumulasi > batas.
  bool get overLimit => accum > pagu;
}
