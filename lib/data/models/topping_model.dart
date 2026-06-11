class Topping {
  final int id;
  final String name;
  final int price; // rupiah integer
  final bool isActive;
  final String? createdAt;

  Topping({
    required this.id,
    required this.name,
    required this.price,
    this.isActive = true,
    this.createdAt,
  });

  factory Topping.fromJson(Map<String, dynamic> j) {
    return Topping(
      id: j['id'],
      name: j['name'] ?? '',
      price: (j['price'] as num?)?.toInt() ?? 0,
      isActive: j['is_active'] as bool? ?? true,
      createdAt: j['created_at'],
    );
  }
}
