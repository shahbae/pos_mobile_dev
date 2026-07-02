/// Saldo stok sebuah topping. Qty bisa desimal (mis. 82.5 gram).
class ToppingStock {
  final int id;
  final int toppingId;
  final String name;
  final String unit;
  final double qty;

  /// Jumlah stok masuk (movement IN) hari ini. Topping desimal — BE kirim string.
  final double incomingToday;

  ToppingStock({
    required this.id,
    required this.toppingId,
    this.name = '',
    this.unit = '',
    this.qty = 0,
    this.incomingToday = 0,
  });

  factory ToppingStock.fromJson(Map<String, dynamic> j) {
    final t = j['topping'] as Map<String, dynamic>?;
    return ToppingStock(
      id: j['id'],
      toppingId: j['topping_id'] ?? t?['id'],
      name: t?['name']?.toString() ?? j['topping_name']?.toString() ?? 'Topping',
      unit: t?['unit']?.toString() ?? '',
      qty: double.tryParse(j['qty']?.toString() ?? '') ?? 0,
      incomingToday: double.tryParse(j['incoming_today']?.toString() ?? '') ?? 0,
    );
  }
}
