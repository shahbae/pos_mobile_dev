class DailyReportRow {
  final String transactionType;
  final int count;
  final String totalAmount;

  const DailyReportRow({
    required this.transactionType,
    required this.count,
    required this.totalAmount,
  });

  num get totalAmountNum => num.tryParse(totalAmount) ?? 0;

  factory DailyReportRow.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    return DailyReportRow(
      transactionType: (json['transaction_type'] ?? '').toString(),
      count: parseInt(json['count']),
      totalAmount: (json['total_amount'] ?? '0').toString(),
    );
  }
}

class DailyReportData {
  final String date;
  final List<DailyReportRow> rows;

  const DailyReportData({required this.date, required this.rows});

  factory DailyReportData.fromJson(Map<String, dynamic> json) {
    final rawRows = (json['rows'] as List?) ?? const [];
    return DailyReportData(
      date: (json['date'] ?? '').toString(),
      rows: rawRows
          .whereType<Map>()
          .map((e) => DailyReportRow.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

