import 'package:pos_mobile/data/models/purchase_template_model.dart';

/// Master sedotan (mis. "Sedotan Kecil"). Mirip Plastik: TANPA harga jual —
/// sedotan gratis untuk pelanggan, hanya menambah COGS.
///
/// COGS per unit = purchase_price / purchase_qty (dihitung BE saat transaksi).
class Sedotan {
  final int id;
  final String name;
  final String unit;
  final String? purchaseQty; // isi 1 paket beli acuan (string desimal)
  final String? purchasePrice; // harga 1 paket beli acuan (string desimal)
  final bool isActive;
  final List<PurchaseTemplate> purchaseTemplates;
  final String? createdAt;

  Sedotan({
    required this.id,
    required this.name,
    this.unit = '',
    this.purchaseQty,
    this.purchasePrice,
    this.isActive = true,
    this.purchaseTemplates = const [],
    this.createdAt,
  });

  factory Sedotan.fromJson(Map<String, dynamic> j) {
    return Sedotan(
      id: j['id'],
      name: j['name']?.toString() ?? '',
      unit: j['unit']?.toString() ?? '',
      purchaseQty: j['purchase_qty']?.toString(),
      purchasePrice: j['purchase_price']?.toString(),
      isActive: _toBool(j['is_active']),
      purchaseTemplates: PurchaseTemplate.listFromJson(j['purchase_templates']),
      createdAt: j['created_at']?.toString(),
    );
  }
}

bool _toBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true' || v == '1';
  return true; // default aktif
}
