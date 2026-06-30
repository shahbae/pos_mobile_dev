import 'package:pos_mobile/data/models/purchase_template_model.dart';

class Topping {
  final int id;
  final String name;
  final int price; // rupiah integer — harga JUAL ke pelanggan
  final bool isActive;
  final int usageQty; // konfigurasi: stok yang dipakai per pemakaian topping
  final String unit;
  final String? purchaseQty; // BARU (2026-06-29): isi 1 paket beli acuan
  final String? purchasePrice; // BARU (2026-06-29): harga 1 paket beli acuan
  final List<PurchaseTemplate> purchaseTemplates;
  final String? createdAt;

  Topping({
    required this.id,
    required this.name,
    required this.price,
    this.isActive = true,
    this.usageQty = 0,
    this.unit = '',
    this.purchaseQty,
    this.purchasePrice,
    this.purchaseTemplates = const [],
    this.createdAt,
  });

  factory Topping.fromJson(Map<String, dynamic> j) {
    return Topping(
      id: j['id'],
      name: j['name'] ?? '',
      price: _toInt(j['price']),
      isActive: _toBool(j['is_active']),
      usageQty: _toInt(j['usage_qty']),
      unit: j['unit']?.toString() ?? '',
      purchaseQty: j['purchase_qty']?.toString(),
      purchasePrice: j['purchase_price']?.toString(),
      purchaseTemplates: PurchaseTemplate.listFromJson(j['purchase_templates']),
      createdAt: j['created_at'],
    );
  }
}

/// Aman untuk num, String ("3000"/"3000.00"), atau null.
int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return double.tryParse(v.toString())?.toInt() ?? 0;
}

bool _toBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true' || v == '1';
  return true; // default aktif
}
