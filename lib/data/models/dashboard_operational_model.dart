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

class DashboardStockAlerts {
  final int threshold;
  final List<dynamic> rows;

  const DashboardStockAlerts({required this.threshold, required this.rows});

  factory DashboardStockAlerts.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    return DashboardStockAlerts(
      threshold: parseInt(json['threshold']),
      rows: (json['rows'] as List?) ?? const [],
    );
  }
}

class DashboardOperationalData {
  final DateTime date;
  final String? primaryTransactionType;
  final DashboardOperationalSummary primarySales;
  final List<dynamic> sales;
  final DashboardOperationalSummary purchases;
  final DashboardOperationalSummary expenses;
  final String net;
  final List<dynamic> payments;
  final DashboardOperationalSummary openBills;
  final DashboardStockAlerts stockAlerts;
  final DashboardOperationalChart? chart;

  const DashboardOperationalData({
    required this.date,
    required this.primaryTransactionType,
    required this.primarySales,
    required this.sales,
    required this.purchases,
    required this.expenses,
    required this.net,
    required this.payments,
    required this.openBills,
    required this.stockAlerts,
    required this.chart,
  });

  num get netNum => num.tryParse(net) ?? 0;

  factory DashboardOperationalData.fromJson(Map<String, dynamic> json) {
    final chartJson = (json['chart'] as Map?)?.cast<String, dynamic>();
    final dateStr = (json['date'] ?? json['from'] ?? '').toString();
    final parsedDate = DateTime.tryParse(dateStr) ?? DateTime(1970);

    return DashboardOperationalData(
      date: parsedDate,
      primaryTransactionType: (json['primary_transaction_type'] as String?)
          ?.toLowerCase(),
      // BE baru mengirim `pos_sales`; `primary_sales` tetap didukung sebagai
      // fallback untuk kontrak lama.
      primarySales: DashboardOperationalSummary.fromJson(
        (json['pos_sales'] as Map?)?.cast<String, dynamic>() ??
            (json['primary_sales'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
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
      stockAlerts: DashboardStockAlerts.fromJson(
        (json['stock_alerts'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      chart: chartJson == null
          ? null
          : DashboardOperationalChart.fromJson(chartJson),
    );
  }
}
