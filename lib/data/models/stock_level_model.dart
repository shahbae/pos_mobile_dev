import 'stock_pack_model.dart';

class StockLevelModel {
  final int? id;
  final int? tenantId;
  final int? productId;
  final int? materialId;
  final int? branchId;

  /// Nama & satuan dasar material (di-enrich BE, tak perlu fetch master).
  final String name;
  final String unit;

  /// Stok material kini DESIMAL (BE kirim string, mis. "2400.5").
  final double qtyOnHand;
  final String? updatedAt;

  /// Jumlah stok masuk (movement IN) hari ini. Desimal (BE kirim string).
  final double incomingToday;

  /// Konversi qty on-hand ke kemasan (PurchaseTemplate). Kosong bila tak ada.
  final List<StockPack> packs;

  StockLevelModel({
    this.id,
    this.tenantId,
    this.productId,
    this.materialId,
    this.branchId,
    this.name = '',
    this.unit = '',
    this.qtyOnHand = 0,
    this.updatedAt,
    this.incomingToday = 0,
    this.packs = const [],
  });

  factory StockLevelModel.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
    return StockLevelModel(
      id: j['id'],
      tenantId: j['tenant_id'],
      productId: j['product_id'],
      materialId: j['material_id'],
      branchId: j['branch_id'],
      name: j['name']?.toString() ?? '',
      unit: j['unit']?.toString() ?? '',
      qtyOnHand: d(j['qty_on_hand']),
      updatedAt: j['updated_at'],
      incomingToday: d(j['incoming_today']),
      packs: StockPack.listFrom(j['packs']),
    );
  }
}
