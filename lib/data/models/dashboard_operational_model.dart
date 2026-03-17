class DashboardOperationalSummary {
  final int count;
  final String totalAmount;

  const DashboardOperationalSummary({
    required this.count,
    required this.totalAmount,
  });

  num get totalAmountNum => num.tryParse(totalAmount) ?? 0;

  factory DashboardOperationalSummary.fromJson(Map<String, dynamic> json) {
    return DashboardOperationalSummary(
      count: json['count'] ?? 0,
      totalAmount: (json['total_amount'] ?? '0').toString(),
    );
  }
}

class DashboardOperationalChartPoint {
  final DateTime time;
  final String revenueTotal;
  final String primaryRevenue;
  final int transactionsTotal;
  final int primaryTransactions;

  const DashboardOperationalChartPoint({
    required this.time,
    required this.revenueTotal,
    required this.primaryRevenue,
    required this.transactionsTotal,
    required this.primaryTransactions,
  });

  num get revenueTotalNum => num.tryParse(revenueTotal) ?? 0;
  num get primaryRevenueNum => num.tryParse(primaryRevenue) ?? 0;

  factory DashboardOperationalChartPoint.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    return DashboardOperationalChartPoint(
      time: DateTime.parse(json['time'] as String),
      revenueTotal: (json['revenue_total'] ?? '0').toString(),
      primaryRevenue: (json['primary_revenue'] ?? '0').toString(),
      transactionsTotal: parseInt(json['transactions_total']),
      primaryTransactions: parseInt(json['primary_transactions']),
    );
  }
}

class DashboardOperationalChart {
  final String interval;
  final List<DashboardOperationalChartPoint> points;

  const DashboardOperationalChart({
    required this.interval,
    required this.points,
  });

  factory DashboardOperationalChart.fromJson(Map<String, dynamic> json) {
    final rawPoints = (json['points'] as List?) ?? const [];
    return DashboardOperationalChart(
      interval: (json['interval'] ?? '').toString(),
      points: rawPoints
          .whereType<Map>()
          .map(
            (e) => DashboardOperationalChartPoint.fromJson(
              e.cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}

class DashboardOperationalData {
  final DateTime from;
  final DateTime to;
  final String? primaryTransactionType;
  final List<dynamic> sales;
  final DashboardOperationalSummary purchases;
  final DashboardOperationalSummary expenses;
  final String net;
  final List<dynamic> payments;
  final DashboardOperationalSummary openBills;
  final DashboardOperationalChart? chart;

  const DashboardOperationalData({
    required this.from,
    required this.to,
    required this.primaryTransactionType,
    required this.sales,
    required this.purchases,
    required this.expenses,
    required this.net,
    required this.payments,
    required this.openBills,
    required this.chart,
  });

  num get netNum => num.tryParse(net) ?? 0;

  factory DashboardOperationalData.fromJson(Map<String, dynamic> json) {
    final chartJson = (json['chart'] as Map?)?.cast<String, dynamic>();

    return DashboardOperationalData(
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
      primaryTransactionType: (json['primary_transaction_type'] as String?)
          ?.toLowerCase(),
      sales: (json['sales'] as List?) ?? const [],
      purchases: DashboardOperationalSummary.fromJson(
        (json['purchases'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      expenses: DashboardOperationalSummary.fromJson(
        (json['expenses'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      net: (json['net'] ?? '0').toString(),
      payments: (json['payments'] as List?) ?? const [],
      openBills: DashboardOperationalSummary.fromJson(
        (json['open_bills'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      chart: chartJson == null
          ? null
          : DashboardOperationalChart.fromJson(chartJson),
    );
  }
}
