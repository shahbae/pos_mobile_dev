/// Model Shift kasir.
class ShiftModel {
  final int id;
  final num openingCash;
  final num? closingCash;
  final num totalSales;
  final num? netCash;
  final List<ShiftPayment> payments;
  final String status; // open / closed
  final DateTime? openedAt;
  final DateTime? closedAt;

  ShiftModel({
    required this.id,
    required this.openingCash,
    required this.closingCash,
    required this.totalSales,
    required this.netCash,
    required this.payments,
    required this.status,
    required this.openedAt,
    required this.closedAt,
  });

  bool get isOpen => status == 'open';

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map) ? json['data'] as Map<String, dynamic> : json;
    final List<dynamic> pays = data['payments'] ?? [];
    return ShiftModel(
      id: data['id'] ?? 0,
      openingCash: _num(data['opening_cash']),
      closingCash: data['closing_cash'] == null ? null : _num(data['closing_cash']),
      totalSales: _num(data['total_sales']),
      netCash: data['net_cash'] == null ? null : _num(data['net_cash']),
      payments: pays.map((e) => ShiftPayment.fromJson(e as Map<String, dynamic>)).toList(),
      status: (data['status'] ?? (data['closed_at'] == null ? 'open' : 'closed')).toString(),
      openedAt: DateTime.tryParse(data['opened_at']?.toString() ?? ''),
      closedAt: DateTime.tryParse(data['closed_at']?.toString() ?? ''),
    );
  }
}

class ShiftPayment {
  final String method;
  final num total;
  final int count;

  ShiftPayment({required this.method, required this.total, required this.count});

  factory ShiftPayment.fromJson(Map<String, dynamic> json) {
    return ShiftPayment(
      method: (json['payment_method'] ?? json['method'])?.toString() ?? '-',
      total: _num(json['total']),
      count: _num(json['count']).toInt(),
    );
  }
}

num _num(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  return num.tryParse(v.toString()) ?? 0;
}
