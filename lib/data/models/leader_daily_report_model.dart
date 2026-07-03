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

/// Ringkasan satu shift dalam laporan harian leader.
class LeaderShiftReport {
  final int shiftId;
  final String shiftName;
  final String cashierName;
  final String status; // open / closed
  final num openingCash; // modal awal
  final num totalSales; // total penjualan (semua metode)
  final int totalItems; // total item terjual
  final int transactionCount; // trafik
  final num cashSales; // cash tanpa modal awal
  final num expenses; // pengeluaran saat shift buka
  final num net; // total_sales - expenses

  const LeaderShiftReport({
    required this.shiftId,
    required this.shiftName,
    required this.cashierName,
    required this.status,
    required this.openingCash,
    required this.totalSales,
    required this.totalItems,
    required this.transactionCount,
    required this.cashSales,
    required this.expenses,
    required this.net,
  });

  bool get isOpen => status.toLowerCase() == 'open';

  factory LeaderShiftReport.fromJson(Map<String, dynamic> json) {
    return LeaderShiftReport(
      shiftId: _int(json['shift_id']),
      shiftName: (json['shift_name'] ?? '').toString(),
      cashierName: (json['cashier_name'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      openingCash: _num(json['opening_cash']),
      totalSales: _num(json['total_sales']),
      totalItems: _int(json['total_items']),
      transactionCount: _int(json['transaction_count']),
      cashSales: _num(json['cash_sales']),
      expenses: _num(json['expenses']),
      net: _num(json['net']),
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

  const LeaderDailyTotals({
    required this.totalSales,
    required this.totalItems,
    required this.transactionCount,
    required this.expenses,
    required this.net,
    required this.totalCash,
  });

  factory LeaderDailyTotals.fromJson(Map<String, dynamic> json) {
    return LeaderDailyTotals(
      totalSales: _num(json['total_sales']),
      totalItems: _int(json['total_items']),
      transactionCount: _int(json['transaction_count']),
      expenses: _num(json['expenses']),
      net: _num(json['net']),
      totalCash: _num(json['total_cash']),
    );
  }

  static const empty = LeaderDailyTotals(
    totalSales: 0,
    totalItems: 0,
    transactionCount: 0,
    expenses: 0,
    net: 0,
    totalCash: 0,
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
  final String date;
  final int? branchId;
  final String branchName;
  final List<LeaderShiftReport> shifts;
  final LeaderDailyTotals totals;
  final LeaderReportChart chart;

  const LeaderDailyReport({
    required this.date,
    required this.branchId,
    required this.branchName,
    required this.shifts,
    required this.totals,
    required this.chart,
  });

  factory LeaderDailyReport.fromJson(Map<String, dynamic> json) {
    final rawShifts = (json['shifts'] as List?) ?? const [];
    final rawTotals = json['totals'];
    final rawChart = json['chart'];
    return LeaderDailyReport(
      date: (json['date'] ?? '').toString(),
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
