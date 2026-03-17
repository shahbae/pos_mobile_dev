class TopProductsRow {
  final int productId;
  final String name;
  final String? sku;
  final int qtySold;
  final String revenue;

  const TopProductsRow({
    required this.productId,
    required this.name,
    required this.sku,
    required this.qtySold,
    required this.revenue,
  });

  num get revenueNum => num.tryParse(revenue) ?? 0;

  factory TopProductsRow.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    return TopProductsRow(
      productId: parseInt(json['product_id']),
      name: (json['name'] ?? '').toString(),
      sku: json['sku']?.toString(),
      qtySold: parseInt(json['qty_sold']),
      revenue: (json['revenue'] ?? '0').toString(),
    );
  }
}

class TopProductsData {
  final DateTime from;
  final DateTime to;
  final List<TopProductsRow> rows;

  const TopProductsData({
    required this.from,
    required this.to,
    required this.rows,
  });

  factory TopProductsData.fromJson(Map<String, dynamic> json) {
    final rawRows = (json['rows'] as List?) ?? const [];
    return TopProductsData(
      from: DateTime.parse((json['from'] ?? '').toString()),
      to: DateTime.parse((json['to'] ?? '').toString()),
      rows: rawRows
          .whereType<Map>()
          .map((e) => TopProductsRow.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

