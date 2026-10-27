// Slip gaji & pinjaman karyawan (Tahap 2 SDM) — cermin docs/api-penggajian-fe.md
// di be-pos. Uang datang sebagai string desimal ("2000000"); tanggal kadang
// "2026-11-27", kadang "2026-11-27T00:00:00+07:00", jadi diseragamkan lewat
// [_ymd].

num _money(dynamic v) => v == null ? 0 : (num.tryParse(v.toString()) ?? 0);

/// Sepuluh huruf pertama = tanggal yang dimaksud BE (zona Asia/Jakarta).
/// Mengurai lewat DateTime lalu toLocal() justru bisa menggeser harinya.
String? _ymd(dynamic v) {
  final s = v?.toString();
  if (s == null || s.length < 10) return null;
  return s.substring(0, 10);
}

DateTime? _time(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// Satu baris di daftar Slip Gaji (`GET /me/payslips`).
class MyPayslipRow {
  final int id;
  final String payday;
  final String periodFrom;
  final String periodTo;
  final num totalEarnings;
  final num totalDeductions;
  final num netPay;
  final String? transferredAt;
  final bool openComplaint;

  const MyPayslipRow({
    required this.id,
    required this.payday,
    required this.periodFrom,
    required this.periodTo,
    required this.totalEarnings,
    required this.totalDeductions,
    required this.netPay,
    required this.transferredAt,
    required this.openComplaint,
  });

  factory MyPayslipRow.fromJson(Map<String, dynamic> j) => MyPayslipRow(
        id: (j['id'] as num).toInt(),
        payday: _ymd(j['payday']) ?? '',
        periodFrom: _ymd(j['period_from']) ?? '',
        periodTo: _ymd(j['period_to']) ?? '',
        totalEarnings: _money(j['total_earnings']),
        totalDeductions: _money(j['total_deductions']),
        netPay: _money(j['net_pay']),
        transferredAt: _ymd(j['transferred_at']),
        openComplaint: j['open_complaint'] == true,
      );
}

/// Lampiran satu baris slip: tanggal tiap lembur, telat, off, alpa, dobel
/// shift, atau tiap pinjaman.
class PayslipDetailItem {
  final String date;
  final String description;
  final int? quantity;
  final num? amount;

  const PayslipDetailItem({required this.date, required this.description, this.quantity, this.amount});

  factory PayslipDetailItem.fromJson(Map<String, dynamic> j) => PayslipDetailItem(
        date: _ymd(j['date']) ?? '',
        description: (j['description'] ?? '').toString(),
        quantity: (j['quantity'] as num?)?.toInt(),
        amount: j['amount'] == null ? null : _money(j['amount']),
      );
}

class PayslipLine {
  final int id;
  final String side; // earning | deduction
  final String kind;
  final String label;
  final int? quantity;
  final String unit;
  final num? rate;
  final num amount;
  final bool manual;
  final String note;
  final List<PayslipDetailItem> details;

  const PayslipLine({
    required this.id,
    required this.side,
    required this.kind,
    required this.label,
    required this.quantity,
    required this.unit,
    required this.rate,
    required this.amount,
    required this.manual,
    required this.note,
    required this.details,
  });

  factory PayslipLine.fromJson(Map<String, dynamic> j) => PayslipLine(
        id: (j['id'] as num?)?.toInt() ?? 0,
        side: (j['side'] ?? '').toString(),
        kind: (j['kind'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        quantity: (j['quantity'] as num?)?.toInt(),
        unit: (j['unit'] ?? '').toString(),
        rate: j['rate'] == null ? null : _money(j['rate']),
        amount: _money(j['amount']),
        manual: j['source'] == 'manual',
        note: (j['note'] ?? '').toString(),
        details: [
          for (final d in (j['details'] as List? ?? const []))
            if (d is Map) PayslipDetailItem.fromJson(Map<String, dynamic>.from(d)),
        ],
      );
}

class PayslipComplaint {
  final int id;
  final String message;
  final String status; // open | accepted | rejected
  final String? response;
  final DateTime? createdAt;
  final DateTime? decidedAt;

  const PayslipComplaint({
    required this.id,
    required this.message,
    required this.status,
    required this.response,
    required this.createdAt,
    required this.decidedAt,
  });

  bool get isOpen => status == 'open';

  String get statusLabel => switch (status) {
        'open' => 'Menunggu keputusan owner',
        'accepted' => 'Diterima',
        'rejected' => 'Ditolak',
        _ => status,
      };

  factory PayslipComplaint.fromJson(Map<String, dynamic> j) => PayslipComplaint(
        id: (j['id'] as num).toInt(),
        message: (j['message'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        response: j['response']?.toString(),
        createdAt: _time(j['created_at']),
        decidedAt: _time(j['decided_at']),
      );
}

/// Rincian satu slip (`GET /me/payslips/:id`). Hanya slip yang periodenya sudah
/// disetujui owner yang bisa dibuka karyawan.
class PayslipView {
  final int id;
  final String userName;
  final String position;
  final String location;
  final String? bankName;
  final String? bankAccount;
  final String payday;
  final String periodFrom;
  final String periodTo;
  final num totalEarnings;
  final num totalDeductions;
  final num netPay;
  final num carryOver;
  final String? transferredAt;
  final List<PayslipLine> earnings;
  final List<PayslipLine> deductions;
  final List<PayslipComplaint> complaints;

  const PayslipView({
    required this.id,
    required this.userName,
    required this.position,
    required this.location,
    required this.bankName,
    required this.bankAccount,
    required this.payday,
    required this.periodFrom,
    required this.periodTo,
    required this.totalEarnings,
    required this.totalDeductions,
    required this.netPay,
    required this.carryOver,
    required this.transferredAt,
    required this.earnings,
    required this.deductions,
    required this.complaints,
  });

  bool get hasOpenComplaint => complaints.any((c) => c.isOpen);

  static List<PayslipLine> _lines(dynamic v) => [
        for (final l in (v as List? ?? const []))
          if (l is Map) PayslipLine.fromJson(Map<String, dynamic>.from(l)),
      ];

  factory PayslipView.fromJson(Map<String, dynamic> j) => PayslipView(
        id: (j['id'] as num).toInt(),
        userName: (j['user_name'] ?? '').toString(),
        position: (j['position'] ?? '').toString(),
        location: (j['location'] ?? '').toString(),
        bankName: j['bank_name']?.toString(),
        bankAccount: j['bank_account']?.toString(),
        payday: _ymd(j['payday']) ?? '',
        periodFrom: _ymd(j['period_from']) ?? '',
        periodTo: _ymd(j['period_to']) ?? '',
        totalEarnings: _money(j['total_earnings']),
        totalDeductions: _money(j['total_deductions']),
        netPay: _money(j['net_pay']),
        carryOver: _money(j['carry_over']),
        transferredAt: _ymd(j['transferred_at']),
        earnings: _lines(j['earnings']),
        deductions: _lines(j['deductions']),
        complaints: [
          for (final c in (j['complaints'] as List? ?? const []))
            if (c is Map) PayslipComplaint.fromJson(Map<String, dynamic>.from(c)),
        ],
      );
}

/// Pinjaman karyawan. Dipakai di riwayat pinjaman sendiri (`/me/loans`) dan di
/// daftar pinjaman tunai yang menunggu diserahkan kasir (`/loans/cash-pending`).
class LoanModel {
  final int id;
  final int userId;
  final String userName;
  final num amount;
  final String purpose;
  final String status;
  final DateTime? requestedAt;
  final DateTime? approvedAt;
  final String? rejectReason;
  final String? disburseMethod;
  final String? disburseBranchName;
  final DateTime? disbursedAt;
  final String? deductPayday;
  final int? payslipId;

  const LoanModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.amount,
    required this.purpose,
    required this.status,
    required this.requestedAt,
    required this.approvedAt,
    required this.rejectReason,
    required this.disburseMethod,
    required this.disburseBranchName,
    required this.disbursedAt,
    required this.deductPayday,
    required this.payslipId,
  });

  /// Batal hanya selama belum diperiksa finance (BE: `requested`).
  bool get cancellable => status == 'requested';

  String get statusLabel => switch (status) {
        'requested' => 'Diajukan',
        'checked' => 'Diperiksa finance',
        'approved' => 'Disetujui, menunggu dicairkan',
        'awaiting_cash' => 'Siap diambil di outlet',
        'disbursed' => 'Sudah cair',
        'rejected' => 'Ditolak',
        'cancelled' => 'Dibatalkan',
        _ => status,
      };

  String get methodLabel => switch (disburseMethod) {
        'transfer' => 'Transfer',
        'cash_finance' => 'Tunai dari finance',
        'cash_drawer' => 'Tunai dari laci outlet',
        _ => '-',
      };

  factory LoanModel.fromJson(Map<String, dynamic> j) => LoanModel(
        id: (j['id'] as num).toInt(),
        userId: (j['user_id'] as num?)?.toInt() ?? 0,
        userName: (j['user_name'] ?? '').toString(),
        amount: _money(j['amount']),
        purpose: (j['purpose'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        requestedAt: _time(j['requested_at']),
        approvedAt: _time(j['approved_at']),
        rejectReason: j['reject_reason']?.toString(),
        disburseMethod: j['disburse_method']?.toString(),
        disburseBranchName: j['disburse_branch_name']?.toString(),
        disbursedAt: _time(j['disbursed_at']),
        deductPayday: _ymd(j['deduct_payday']),
        payslipId: (j['payslip_id'] as num?)?.toInt(),
      );
}
