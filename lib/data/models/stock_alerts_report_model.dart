class StockAlertsRow {
  final int productId;
  final String name;
  final String? sku;
  final int qtyOnHand;
  final DateTime updatedAt;

  const StockAlertsRow({
    required this.productId,
    required this.name,
    required this.sku,
    required this.qtyOnHand,
    required this.updatedAt,
  });

  factory StockAlertsRow.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    return StockAlertsRow(
      productId: parseInt(json['product_id']),
      name: (json['name'] ?? '').toString(),
      sku: json['sku']?.toString(),
      qtyOnHand: parseInt(json['qty_on_hand']),
      updatedAt: DateTime.parse((json['updated_at'] ?? '').toString()),
    );
  }
}

class StockAlertsData {
  final int threshold;
  final List<StockAlertsRow> rows;

  const StockAlertsData({
    required this.threshold,
    required this.rows,
  });

  factory StockAlertsData.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    final rawRows = (json['rows'] as List?) ?? const [];
    return StockAlertsData(
      threshold: parseInt(json['threshold']),
      rows: rawRows
          .whereType<Map>()
          .map((e) => StockAlertsRow.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

