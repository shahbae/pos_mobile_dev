class ProductCategory {
  final int id;
  final int? tenantId;
  final String name;
  final String? createdAt;

  ProductCategory({
    required this.id,
    this.tenantId,
    required this.name,
    this.createdAt,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'],
      tenantId: json['tenant_id'],
      name: json['name'],
      createdAt: json['created_at'],
    );
  }
}
