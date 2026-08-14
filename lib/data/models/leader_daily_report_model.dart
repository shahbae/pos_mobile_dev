// Model laporan harian leader — rekap 1 hari dipecah per shift.
// Endpoint: GET /reports/leader/daily (role owner/supervisor/leader).

num _num(dynamic raw) {
  if (raw is num) return raw;
  return num.tryParse(raw?.toString() ?? '') ?? 0;
}

int _int(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

/// Seperti [_num] tapi mempertahankan `null` — dipakai untuk angka laci yang
/// memang belum ada selama shift masih buka (jangan dianggap 0).
num? _numOrNull(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw;
  return num.tryParse(raw.toString());
}

/// Ringkasan satu shift dalam laporan harian leader.
class LeaderShiftReport {
  final int shiftId;
  final String shiftDate; // "YYYY-MM-DD" — relevan saat rentang > 1 hari
  final String shiftName;
  final String cashierName;
  final String status; // open / closed
  final num openingCash; // modal awal
  final num totalSales; // total penjualan (semua metode)
  final int totalItems; // total item terjual
  final int transactionCount; // trafik
  final num cashSales; // cash tanpa modal awal
  final num qrisSales; // penjualan lewat QRIS
  final num expenses; // pengeluaran saat shift buka
  final num net; // total_sales - expenses
  final num? closingCash; // kas fisik saat tutup; null selama shift buka
  final num expectedCash; // opening_cash + cash_sales - expenses
  final num? difference; // closing_cash - expected_cash; null selama buka

  const LeaderShiftReport({
    required this.shiftId,
    required this.shiftDate,
    required this.shiftName,
    required this.cashierName,
    required this.status,
    required this.openingCash,
    required this.totalSales,
    required this.totalItems,
    required this.transactionCount,
    required this.cashSales,
    required this.qrisSales,
    required this.expenses,
    required this.net,
    required this.closingCash,
    required this.expectedCash,
    required this.difference,
  });

  bool get isOpen => status.toLowerCase() == 'open';

  factory LeaderShiftReport.fromJson(Map<String, dynamic> json) {
    return LeaderShiftReport(
      shiftId: _int(json['shift_id']),
      shiftDate: (json['shift_date'] ?? '').toString(),
      shiftName: (json['shift_name'] ?? '').toString(),
      cashierName: (json['cashier_name'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      openingCash: _num(json['opening_cash']),
      totalSales: _num(json['total_sales']),
      totalItems: _int(json['total_items']),
      transactionCount: _int(json['transaction_count']),
      cashSales: _num(json['cash_sales']),
      qrisSales: _num(json['qris_sales']),
      expenses: _num(json['expenses']),
      net: _num(json['net']),
      closingCash: _numOrNull(json['closing_cash']),
      expectedCash: _num(json['expected_cash']),
      difference: _numOrNull(json['difference']),
    );
  }
}

/// Total harian gabungan semua shift.
class LeaderDailyTotals {
  final num totalSales;
  final int totalItems;
  final int transactionCount;
  final num expenses;
  final num net;
  final num totalCash; // Σ cash_sales (tanpa modal awal)
  final num totalQris; // Σ qris_sales
  final num openingCash; // Σ modal awal
  final num closingCash; // Σ kas fisik — hanya shift yang sudah ditutup
  final num expectedCash; // Σ kas seharusnya
  final num difference; // Σ selisih — hanya shift yang sudah ditutup

  const LeaderDailyTotals({
    required this.totalSales,
    required this.totalItems,
    required this.transactionCount,
    required this.expenses,
    required this.net,
    required this.totalCash,
    required this.totalQris,
    required this.openingCash,
    required this.closingCash,
    required this.expectedCash,
    required this.difference,
  });

  factory LeaderDailyTotals.fromJson(Map<String, dynamic> json) {
    return LeaderDailyTotals(
      totalSales: _num(json['total_sales']),
      totalItems: _int(json['total_items']),
      transactionCount: _int(json['transaction_count']),
      expenses: _num(json['expenses']),
      net: _num(json['net']),
      totalCash: _num(json['total_cash']),
      totalQris: _num(json['total_qris']),
      openingCash: _num(json['opening_cash']),
      closingCash: _num(json['closing_cash']),
      expectedCash: _num(json['expected_cash']),
      difference: _num(json['difference']),
    );
  }

  static const empty = LeaderDailyTotals(
    totalSales: 0,
    totalItems: 0,
    transactionCount: 0,
    expenses: 0,
    net: 0,
    totalCash: 0,
    totalQris: 0,
    openingCash: 0,
    closingCash: 0,
    expectedCash: 0,
    difference: 0,
  );
}

/// Satu titik grafik trafik penjualan per jam, ditandai shift-nya.
class LeaderChartPoint {
  final DateTime time; // awal jam bucket (RFC3339)
  final int shiftId;
  final String shiftName;
  final num revenueTotal; // total penjualan pada jam itu
  final int transactions; // jumlah transaksi pada jam itu

  const LeaderChartPoint({
    required this.time,
    required this.shiftId,
    required this.shiftName,
    required this.revenueTotal,
    required this.transactions,
  });

  factory LeaderChartPoint.fromJson(Map<String, dynamic> json) {
    return LeaderChartPoint(
      time: DateTime.tryParse((json['time'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      shiftId: _int(json['shift_id']),
      shiftName: (json['shift_name'] ?? '').toString(),
      revenueTotal: _num(json['revenue_total']),
      transactions: _int(json['transactions']),
    );
  }
}

/// Grafik time-series penjualan sepanjang hari (per jam, per shift).
class LeaderReportChart {
  final String interval; // granularitas bucket, mis. "1hour"
  final List<LeaderChartPoint> points;

  const LeaderReportChart({required this.interval, required this.points});

  bool get isEmpty => points.isEmpty;

  factory LeaderReportChart.fromJson(Map<String, dynamic> json) {
    final rawPoints = (json['points'] as List?) ?? const [];
    return LeaderReportChart(
      interval: (json['interval'] ?? '').toString(),
      points: rawPoints
          .whereType<Map>()
          .map((e) => LeaderChartPoint.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  static const empty = LeaderReportChart(interval: '', points: []);
}

class LeaderDailyReport {
  final String date; // = from; dipertahankan BE demi kompatibilitas
  final String from; // awal rentang, inklusif
  final String to; // akhir rentang, inklusif
  final int? branchId;
  final String branchName;
  final List<LeaderShiftReport> shifts;
  final LeaderDailyTotals totals;
  final LeaderReportChart chart;

  const LeaderDailyReport({
    required this.date,
    required this.from,
    required this.to,
    required this.branchId,
    required this.branchName,
    required this.shifts,
    required this.totals,
    required this.chart,
  });

  /// Rentang mencakup lebih dari satu hari? Kalau ya, tanggal tiap shift
  /// perlu ditampilkan supaya barisnya tidak ambigu.
  bool get isMultiDay => from.isNotEmpty && to.isNotEmpty && from != to;

  factory LeaderDailyReport.fromJson(Map<String, dynamic> json) {
    final rawShifts = (json['shifts'] as List?) ?? const [];
    final rawTotals = json['totals'];
    final rawChart = json['chart'];
    final date = (json['date'] ?? '').toString();
    return LeaderDailyReport(
      date: date,
      from: (json['from'] ?? date).toString(),
      to: (json['to'] ?? date).toString(),
      branchId: json['branch_id'] == null ? null : _int(json['branch_id']),
      branchName: (json['branch_name'] ?? '').toString(),
      shifts: rawShifts
          .whereType<Map>()
          .map((e) => LeaderShiftReport.fromJson(e.cast<String, dynamic>()))
          .toList(),
      totals: rawTotals is Map
          ? LeaderDailyTotals.fromJson(rawTotals.cast<String, dynamic>())
          : LeaderDailyTotals.empty,
      chart: rawChart is Map
          ? LeaderReportChart.fromJson(rawChart.cast<String, dynamic>())
          : LeaderReportChart.empty,
    );
  }
}
