import 'package:pos_mobile/data/models/purchase_template_model.dart';

/// Master plastik/kemasan (mis. "Plastik Cup 1"). Mirip Topping tapi TANPA
/// harga jual — plastik gratis untuk pelanggan, hanya menambah COGS.
///
/// COGS per unit = purchase_price / purchase_qty (dihitung BE saat transaksi).
class Plastic {
  final int id;
  final String name;
  final String unit;
  final String? purchaseQty; // isi 1 paket beli acuan (string desimal)
  final String? purchasePrice; // harga 1 paket beli acuan (string desimal)
  /// "wadah" = menempel pada minumannya (cup, sealer); dipotong otomatis lewat
  /// aturan kemasan varian dan TIDAK dipotong kalau pembeli bawa tumbler.
  /// "bungkus" = kantong bawa pulang; tetap dipilih manual oleh kasir.
  final String packagingType;
  final bool isActive;
  final List<PurchaseTemplate> purchaseTemplates;
  final String? createdAt;

  Plastic({
    required this.id,
    required this.name,
    this.unit = '',
    this.purchaseQty,
    this.purchasePrice,
    this.packagingType = 'bungkus',
    this.isActive = true,
    this.purchaseTemplates = const [],
    this.createdAt,
  });

  factory Plastic.fromJson(Map<String, dynamic> j) {
    return Plastic(
      id: j['id'],
      name: j['name']?.toString() ?? '',
      unit: j['unit']?.toString() ?? '',
      purchaseQty: j['purchase_qty']?.toString(),
      purchasePrice: j['purchase_price']?.toString(),
      packagingType: j['packaging_type']?.toString() ?? 'bungkus',
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

/// Plastik yang dipilih manual oleh kasir. Wadah (cup, sealer) sudah dipotong
/// otomatis oleh backend, jadi menampilkannya lagi sebagai pilihan manual akan
/// memotong stok dua kali.
extension PlasticPackaging on Plastic {
  bool get isWadah => packagingType == 'wadah';
  bool get isPickedManually => !isWadah;
}
