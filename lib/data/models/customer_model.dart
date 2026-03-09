class Customer {
  final int id;
  final int? tenantId;
  final String name;
  final String? phone;
  final String? address;
  final String? createdAt;

  Customer({
    required this.id,
    this.tenantId,
    required this.name,
    this.phone,
    this.address,
    this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> j) {
    return Customer(
      id: j['id'],
      tenantId: j['tenant_id'],
      name: j['name'],
      phone: j['phone'],
      address: j['address'],
      createdAt: j['created_at'],
    );
  }
}
