import 'package:pos_mobile/data/models/dashboard_operational_model.dart';

/// Helper parse angka dari num/String.
num _num(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '') ?? 0);
int _int(dynamic v) => _num(v).toInt();

/// Dashboard adaptif per-role (GET /dashboard, revisi BE 2026-06-29).
/// Satu endpoint, section menyesuaikan role dari token.
class DashboardData {
  final String role;
  final String? from;
  final String? to;
  final int? branchId;

  /// Penjualan bersih = penjualan − pengeluaran (string desimal dari BE).
  /// Beda dari [DashboardOperationalData.net] yang juga mengurangi pembelian.
  /// null bila BE tidak mengirim untuk role ini.
  final num? netSales;

  /// Section operasional (= struktur GET /dashboard/operational).
  final DashboardOperationalData? operational;

  /// Section lain (parse defensif; null/empty bila tak dikirim untuk role ini).
  final DashboardProfit? profit;
  final List<DashboardPaymentRow> payments;
  final List<DashboardTopProduct> topProducts;
  final List<DashboardBranchRow> perBranch;
  final DashboardShift? currentShift;
  final List<DashboardAttendanceRow> teamAttendance;
  final List<DashboardRecentTx> recentTransactions;
  final DashboardAttendanceDay? attendanceToday;
  final List<DashboardAttendanceDay> attendanceHistory;
  final Map<String, dynamic> raw;

  const DashboardData({
    required this.role,
    this.from,
    this.to,
    this.branchId,
    this.netSales,
    this.operational,
    this.profit,
    this.payments = const [],
    this.topProducts = const [],
    this.perBranch = const [],
    this.currentShift,
    this.teamAttendance = const [],
    this.recentTransactions = const [],
    this.attendanceToday,
    this.attendanceHistory = const [],
    this.raw = const {},
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic>? asMap(dynamic v) =>
        v is Map ? v.cast<String, dynamic>() : null;
    List<dynamic> asList(dynamic v) => v is List ? v : const [];

    final op = asMap(j['operational']);

    // payments bisa berupa list langsung, atau {rows:[...]} (mirip /reports/payments).
    final rawPayments = j['payments'];
    final List paymentsList = rawPayments is List
        ? rawPayments
        : (asMap(rawPayments)?['rows'] as List? ?? const []);

    // top_products: objek {rows:[...]} (owner/supervisor/leader) atau list langsung.
    final rawTop = j['top_products'];
    final List topProductsList =
        rawTop is List ? rawTop : (asMap(rawTop)?['rows'] as List? ?? const []);

    // team_attendance: objek {items:[...]} atau list langsung.
    final rawTeam = j['team_attendance'];
    final List teamList =
        rawTeam is List ? rawTeam : (asMap(rawTeam)?['items'] as List? ?? const []);

    return DashboardData(
      role: (j['role'] ?? '').toString(),
      from: j['from']?.toString(),
      to: j['to']?.toString(),
      branchId: j['branch_id'] == null ? null : _int(j['branch_id']),
      netSales: j['net_sales'] == null ? null : _num(j['net_sales']),
      operational: op == null ? null : DashboardOperationalData.fromJson(op),
      profit: asMap(j['profit']) == null
          ? null
          : DashboardProfit.fromJson(asMap(j['profit'])!),
      payments: paymentsList
          .whereType<Map>()
          .map((e) => DashboardPaymentRow.fromJson(e.cast<String, dynamic>()))
          .toList(),
      topProducts: topProductsList
          .whereType<Map>()
          .map((e) => DashboardTopProduct.fromJson(e.cast<String, dynamic>()))
          .toList(),
      perBranch: asList(j['per_branch'])
          .whereType<Map>()
          .map((e) => DashboardBranchRow.fromJson(e.cast<String, dynamic>()))
          .toList(),
      currentShift: asMap(j['current_shift']) == null
          ? null
          : DashboardShift.fromJson(asMap(j['current_shift'])!),
      teamAttendance: teamList
          .whereType<Map>()
          .map((e) => DashboardAttendanceRow.fromJson(e.cast<String, dynamic>()))
          .toList(),
      recentTransactions: asList(j['recent_transactions'])
          .whereType<Map>()
          .map((e) => DashboardRecentTx.fromJson(e.cast<String, dynamic>()))
          .toList(),
      attendanceToday: asMap(j['attendance_today']) == null
          ? null
          : DashboardAttendanceDay.fromJson(asMap(j['attendance_today'])!),
      attendanceHistory: asList(j['attendance_history'])
          .whereType<Map>()
          .map((e) => DashboardAttendanceDay.fromJson(e.cast<String, dynamic>()))
          .toList(),
      raw: j,
    );
  }
}

class DashboardProfit {
  final num revenue;
  final num cogs;
  final num grossProfit;
  final num expenses;
  final num netProfit;

  const DashboardProfit({
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.expenses,
    required this.netProfit,
  });

  factory DashboardProfit.fromJson(Map<String, dynamic> j) {
    return DashboardProfit(
      revenue: _num(j['revenue'] ?? j['gross_revenue'] ?? j['total_revenue']),
      cogs: _num(j['cogs'] ?? j['total_cogs']),
      grossProfit: _num(j['gross_profit'] ?? j['gross']),
      expenses: _num(j['expenses'] ?? j['total_expenses']),
      netProfit: _num(j['net_profit'] ?? j['net'] ?? j['profit']),
    );
  }
}

class DashboardPaymentRow {
  final String method;
  final num total;
  final int count;

  const DashboardPaymentRow({
    required this.method,
    required this.total,
    this.count = 0,
  });

  factory DashboardPaymentRow.fromJson(Map<String, dynamic> j) {
    return DashboardPaymentRow(
      method: (j['payment_method'] ?? j['method'] ?? '').toString(),
      total: _num(j['total'] ?? j['total_paid'] ?? j['amount']),
      count: _int(j['count']),
    );
  }
}

class DashboardTopProduct {
  final String name;
  final String? variantName;
  final int qty;
  final num total;

  const DashboardTopProduct({
    required this.name,
    this.variantName,
    this.qty = 0,
    this.total = 0,
  });

  /// Nama tampilan: "Produk - Varian" bila ada varian.
  String get displayName =>
      (variantName != null && variantName!.isNotEmpty) ? '$name - $variantName' : name;

  factory DashboardTopProduct.fromJson(Map<String, dynamic> j) {
    final vn = j['variant_name']?.toString();
    return DashboardTopProduct(
      name: (j['name'] ?? j['product_name'] ?? '-').toString(),
      variantName: (vn == null || vn.isEmpty) ? null : vn,
      qty: _int(j['qty_sold'] ?? j['qty'] ?? j['quantity'] ?? j['total_qty']),
      total: _num(j['revenue'] ?? j['total'] ?? j['total_amount']),
    );
  }
}

class DashboardBranchRow {
  final int? branchId;
  final String name;
  final num sales;
  final int transactions;

  const DashboardBranchRow({
    this.branchId,
    required this.name,
    this.sales = 0,
    this.transactions = 0,
  });

  factory DashboardBranchRow.fromJson(Map<String, dynamic> j) {
    return DashboardBranchRow(
      branchId: j['branch_id'] == null ? null : _int(j['branch_id']),
      name: (j['name'] ?? j['branch_name'] ?? '-').toString(),
      sales: _num(j['sales'] ?? j['total_sales'] ?? j['revenue']),
      transactions: _int(j['transactions'] ?? j['count'] ?? j['transaction_count']),
    );
  }
}

class DashboardShift {
  final String shiftName;
  final String cashierName;
  final num openingCash;

  /// Tunai masuk dari penjualan cash (field baru BE).
  final num cashSales;
  final num totalSales;
  final num expectedCash;

  /// null selama shift masih `open`; terisi setelah shift ditutup.
  final num? closingCash;
  final num? difference;
  final String status;
  final List<DashboardPaymentRow> payments;

  /// Top product selama shift ini (dikirim BE untuk kasir).
  final List<DashboardTopProduct> topProducts;

  const DashboardShift({
    this.shiftName = '',
    required this.cashierName,
    required this.openingCash,
    this.cashSales = 0,
    required this.totalSales,
    required this.expectedCash,
    this.closingCash,
    this.difference,
    required this.status,
    this.payments = const [],
    this.topProducts = const [],
  });

  bool get isOpen => status.toLowerCase() == 'open';

  factory DashboardShift.fromJson(Map<String, dynamic> j) {
    final pays = (j['payments'] as List?) ?? const [];
    final tops = (j['top_products'] as List?) ?? const [];
    return DashboardShift(
      shiftName: (j['shift_name'] ?? '').toString(),
      cashierName: (j['cashier_name'] ?? '-').toString(),
      openingCash: _num(j['opening_cash']),
      cashSales: _num(j['cash_sales']),
      totalSales: _num(j['total_sales']),
      expectedCash: _num(j['expected_cash']),
      closingCash: j['closing_cash'] == null ? null : _num(j['closing_cash']),
      difference: j['difference'] == null ? null : _num(j['difference']),
      status: (j['status'] ?? '').toString(),
      payments: pays
          .whereType<Map>()
          .map((e) => DashboardPaymentRow.fromJson(e.cast<String, dynamic>()))
          .toList(),
      topProducts: tops
          .whereType<Map>()
          .map((e) => DashboardTopProduct.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class DashboardAttendanceRow {
  final String name;
  final String role;
  final int totalDays;
  final int shift1Days;
  final int shift2Days;
  final int middleDays;
  final int noCheckoutDays;
  final int outsideRadiusDays;

  const DashboardAttendanceRow({
    required this.name,
    this.role = '',
    this.totalDays = 0,
    this.shift1Days = 0,
    this.shift2Days = 0,
    this.middleDays = 0,
    this.noCheckoutDays = 0,
    this.outsideRadiusDays = 0,
  });

  factory DashboardAttendanceRow.fromJson(Map<String, dynamic> j) {
    return DashboardAttendanceRow(
      name: (j['user_name'] ?? j['name'] ?? j['employee_name'] ?? '-').toString(),
      role: (j['user_role'] ?? j['role'] ?? '').toString(),
      totalDays: _int(j['total_days']),
      shift1Days: _int(j['shift_1_days']),
      shift2Days: _int(j['shift_2_days']),
      middleDays: _int(j['middle_days']),
      noCheckoutDays: _int(j['no_checkout_days']),
      outsideRadiusDays: _int(j['outside_radius_days']),
    );
  }
}

class DashboardRecentTx {
  final String invoiceNo;
  final num total;
  final String paymentMethod;
  final String? customerName;

  /// Nama kasir/pembuat transaksi (field baru BE).
  final String? actorName;
  final DateTime? createdAt;

  const DashboardRecentTx({
    required this.invoiceNo,
    this.total = 0,
    this.paymentMethod = '',
    this.customerName,
    this.actorName,
    this.createdAt,
  });

  factory DashboardRecentTx.fromJson(Map<String, dynamic> j) {
    final ts = (j['created_at'] ?? j['time'])?.toString();
    final actor = j['actor_name']?.toString();
    return DashboardRecentTx(
      invoiceNo:
          (j['invoice_number'] ?? j['invoice_no'] ?? j['invoice'] ?? j['id'] ?? '-')
              .toString(),
      total: _num(j['amount'] ?? j['total_amount'] ?? j['total']),
      paymentMethod: (j['payment_method'] ?? '').toString(),
      customerName: j['customer_name']?.toString(),
      actorName: (actor == null || actor.isEmpty) ? null : actor,
      createdAt: ts == null ? null : DateTime.tryParse(ts),
    );
  }
}

/// Satu hari catatan absensi (untuk attendance_today & attendance_history).
class DashboardAttendanceDay {
  final DateTime? date;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final String status;
  final String shift;

  const DashboardAttendanceDay({
    this.date,
    this.checkInAt,
    this.checkOutAt,
    this.status = '',
    this.shift = '',
  });

  factory DashboardAttendanceDay.fromJson(Map<String, dynamic> j) {
    DateTime? d(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    return DashboardAttendanceDay(
      date: d(j['date'] ?? j['created_at']),
      checkInAt: d(j['check_in_at'] ?? j['check_in'] ?? j['checkin_time']),
      checkOutAt: d(j['check_out_at'] ?? j['check_out'] ?? j['checkout_time']),
      status: (j['status'] ?? '').toString(),
      shift: (j['shift'] ?? '').toString(),
    );
  }

  bool get hasCheckedIn => checkInAt != null;
  bool get hasCheckedOut => checkOutAt != null;
}
