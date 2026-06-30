class ProductCategory {
  final int id;
  final int? tenantId;
  final String name;
  final bool freeable; // boleh dijadikan item gratis promo (default true)
  final String? createdAt;

  ProductCategory({
    required this.id,
    this.tenantId,
    required this.name,
    this.freeable = true,
    this.createdAt,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'],
      tenantId: json['tenant_id'],
      name: json['name'],
      freeable: _toBool(json['freeable']),
      createdAt: json['created_at'],
    );
  }
}

/// Default true bila tidak dikirim (BE: freeable default true).
bool _toBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() != 'false' && v != '0';
  return true;
}
