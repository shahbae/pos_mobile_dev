class ServiceModel {
  final int id;
  final int? tenantId;
  final String name;
  final String price;
  final String? unitType;
  final String? createdAt;

  ServiceModel({
    required this.id,
    this.tenantId,
    required this.name,
    required this.price,
    this.unitType,
    this.createdAt,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> j) {
    return ServiceModel(
      id: j['id'],
      tenantId: j['tenant_id'],
      name: j['name'],
      price: j['price']?.toString() ?? '0',
      unitType: j['unit_type'],
      createdAt: j['created_at'],
    );
  }

  /// Helper to get numeric price for formatting
  num get priceNum => num.tryParse(price) ?? 0;
}
