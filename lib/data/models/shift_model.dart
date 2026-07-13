/// Model Shift kasir.
class ShiftModel {
  final int id;
  final num openingCash;
  final num? closingCash;
  final num totalSales;
  final num? cashSales; // tunai bersih masuk laci (BE: cash_sales, dulu net_cash)
  final num? expectedCash; // kas seharusnya (dari BE bila tersedia)
  final num totalExpense; // total pengeluaran shift (BE: total_expense)
  final num? difference; // selisih kas (dari BE bila tersedia)
  final List<ShiftPayment> payments;
  final String status; // open / closed
  final DateTime? openedAt;
  final DateTime? closedAt;

  ShiftModel({
    required this.id,
    required this.openingCash,
    required this.closingCash,
    required this.totalSales,
    required this.cashSales,
    required this.expectedCash,
    this.totalExpense = 0,
    required this.difference,
    required this.payments,
    required this.status,
    required this.openedAt,
    required this.closedAt,
  });

  bool get isOpen => status == 'open';

  /// Total penjualan tunai (metode cash) dari breakdown pembayaran — fallback
  /// bila BE tidak mengirim `cash_sales`.
  num get _cashFromPayments => payments
      .where((p) => p.method.toLowerCase() == 'cash')
      .fold<num>(0, (sum, p) => sum + p.total);

  /// Tunai bersih masuk laci. Pakai nilai BE (`cash_sales`) bila ada, kalau
  /// tidak dihitung dari breakdown pembayaran.
  num get cashSalesResolved => cashSales ?? _cashFromPayments;

  /// Kas seharusnya — diambil langsung dari BE (`expected_cash`), yang sudah
  /// memperhitungkan pengeluaran (kas awal + penjualan tunai − pengeluaran),
  /// selaras dengan dashboard `current_shift`. FE tidak menghitung sendiri;
  /// 0 bila BE tidak mengirimnya.
  num get expectedCashResolved => expectedCash ?? 0;

  /// Selisih kas = kas fisik (kas akhir) - kas seharusnya.
  /// Positif = lebih, negatif = kurang. null bila shift belum ditutup.
  num? get differenceResolved {
    if (difference != null) return difference;
    if (closingCash == null) return null;
    return closingCash! - expectedCashResolved;
  }

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map) ? json['data'] as Map<String, dynamic> : json;
    final List<dynamic> pays = data['payments'] ?? [];
    return ShiftModel(
      id: data['id'] ?? 0,
      openingCash: _num(data['opening_cash']),
      closingCash: data['closing_cash'] == null ? null : _num(data['closing_cash']),
      totalSales: _num(data['total_sales']),
      cashSales: (data['cash_sales'] ?? data['net_cash']) == null
          ? null
          : _num(data['cash_sales'] ?? data['net_cash']),
      expectedCash: data['expected_cash'] == null ? null : _num(data['expected_cash']),
      totalExpense: _num(data['total_expense']),
      difference: (data['difference'] ?? data['cash_difference']) == null
          ? null
          : _num(data['difference'] ?? data['cash_difference']),
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
