import 'package:pos_mobile/data/models/purchase_template_model.dart';

/// Master sedotan (mis. "Sedotan Kecil"). Mirip Plastik: TANPA harga jual —
/// sedotan gratis untuk pelanggan, hanya menambah COGS.
///
/// COGS per unit = purchase_price / purchase_qty (dihitung BE saat transaksi).
///
/// [autoFor] menentukan sedotan mana yang diisi otomatis di checkout dari isi
/// keranjang — lihat [SedotanAutoFor].
class Sedotan {
  final int id;
  final String name;
  final String unit;
  final String? purchaseQty; // isi 1 paket beli acuan (string desimal)
  final String? purchasePrice; // harga 1 paket beli acuan (string desimal)
  final bool isActive;
  final String autoFor; // with_topping | without_topping | none
  final List<PurchaseTemplate> purchaseTemplates;
  final String? createdAt;

  Sedotan({
    required this.id,
    required this.name,
    this.unit = '',
    this.purchaseQty,
    this.purchasePrice,
    this.isActive = true,
    this.autoFor = SedotanAutoFor.none,
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
      // BE lama belum mengirim auto_for: anggap manual, jadi tak ada yang terisi.
      autoFor: j['auto_for']?.toString() ?? SedotanAutoFor.none,
      purchaseTemplates: PurchaseTemplate.listFromJson(j['purchase_templates']),
      createdAt: j['created_at']?.toString(),
    );
  }
}

/// Nilai `auto_for` dari BE. Satu penanda (selain none) dipegang maksimal satu
/// sedotan — BE yang menjaganya.
abstract final class SedotanAutoFor {
  /// Gelas di baris bertopping (topping bertekstur butuh sedotan besar).
  static const withTopping = 'with_topping';

  /// Gelas di baris tanpa topping, termasuk bonus promo.
  static const withoutTopping = 'without_topping';

  /// Tidak diisi otomatis; kasir memilih sendiri (mis. Tutup Cup).
  static const none = 'none';
}

bool _toBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true' || v == '1';
  return true; // default aktif
}
