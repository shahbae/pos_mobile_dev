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

class DashboardOperationalData {
  final DateTime from;
  final DateTime to;
  final List<dynamic> sales;
  final DashboardOperationalSummary purchases;
  final DashboardOperationalSummary expenses;
  final String net;
  final List<dynamic> payments;
  final DashboardOperationalSummary openBills;

  const DashboardOperationalData({
    required this.from,
    required this.to,
    required this.sales,
    required this.purchases,
    required this.expenses,
    required this.net,
    required this.payments,
    required this.openBills,
  });

  num get netNum => num.tryParse(net) ?? 0;

  factory DashboardOperationalData.fromJson(Map<String, dynamic> json) {
    return DashboardOperationalData(
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
      sales: (json['sales'] as List?) ?? const [],
      purchases: DashboardOperationalSummary.fromJson(
        (json['purchases'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      ),
      expenses: DashboardOperationalSummary.fromJson(
        (json['expenses'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      ),
      net: (json['net'] ?? '0').toString(),
      payments: (json['payments'] as List?) ?? const [],
      openBills: DashboardOperationalSummary.fromJson(
        (json['open_bills'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      ),
    );
  }
}

