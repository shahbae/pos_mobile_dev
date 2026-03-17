class ProfitReportData {
  final DateTime from;
  final DateTime to;
  final String revenueProduct;
  final String revenueService;
  final String revenueTotal;
  final String cogs;
  final String grossProfit;
  final String grossMarginPercent;
  final String expenses;
  final String netProfit;
  final String cogsMethod;

  const ProfitReportData({
    required this.from,
    required this.to,
    required this.revenueProduct,
    required this.revenueService,
    required this.revenueTotal,
    required this.cogs,
    required this.grossProfit,
    required this.grossMarginPercent,
    required this.expenses,
    required this.netProfit,
    required this.cogsMethod,
  });

  num get revenueProductNum => num.tryParse(revenueProduct) ?? 0;
  num get revenueServiceNum => num.tryParse(revenueService) ?? 0;
  num get revenueTotalNum => num.tryParse(revenueTotal) ?? 0;
  num get cogsNum => num.tryParse(cogs) ?? 0;
  num get grossProfitNum => num.tryParse(grossProfit) ?? 0;
  double get grossMarginPercentNum => double.tryParse(grossMarginPercent) ?? 0;
  num get expensesNum => num.tryParse(expenses) ?? 0;
  num get netProfitNum => num.tryParse(netProfit) ?? 0;

  factory ProfitReportData.fromJson(Map<String, dynamic> json) {
    return ProfitReportData(
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
      revenueProduct: (json['revenue_product'] ?? '0').toString(),
      revenueService: (json['revenue_service'] ?? '0').toString(),
      revenueTotal: (json['revenue_total'] ?? '0').toString(),
      cogs: (json['cogs'] ?? '0').toString(),
      grossProfit: (json['gross_profit'] ?? '0').toString(),
      grossMarginPercent: (json['gross_margin_percent'] ?? '0').toString(),
      expenses: (json['expenses'] ?? '0').toString(),
      netProfit: (json['net_profit'] ?? '0').toString(),
      cogsMethod: (json['cogs_method'] ?? '').toString(),
    );
  }
}

