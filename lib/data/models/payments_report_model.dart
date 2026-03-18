class PaymentsReportRow {
  final String paymentMethod;
  final String paymentStatus;
  final int count;
  final String totalPaid;
  final String totalChange;

  const PaymentsReportRow({
    required this.paymentMethod,
    required this.paymentStatus,
    required this.count,
    required this.totalPaid,
    required this.totalChange,
  });

  num get totalPaidNum => num.tryParse(totalPaid) ?? 0;
  num get totalChangeNum => num.tryParse(totalChange) ?? 0;

  factory PaymentsReportRow.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    return PaymentsReportRow(
      paymentMethod: (json['payment_method'] ?? '').toString(),
      paymentStatus: (json['payment_status'] ?? '').toString(),
      count: parseInt(json['count']),
      totalPaid: (json['total_paid'] ?? '0').toString(),
      totalChange: (json['total_change'] ?? '0').toString(),
    );
  }
}

class PaymentsReportData {
  final DateTime from;
  final DateTime to;
  final List<PaymentsReportRow> rows;

  const PaymentsReportData({
    required this.from,
    required this.to,
    required this.rows,
  });

  factory PaymentsReportData.fromJson(Map<String, dynamic> json) {
    final rawRows = (json['rows'] as List?) ?? const [];
    return PaymentsReportData(
      from: DateTime.parse((json['from'] ?? '').toString()),
      to: DateTime.parse((json['to'] ?? '').toString()),
      rows: rawRows
          .whereType<Map>()
          .map((e) => PaymentsReportRow.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}
