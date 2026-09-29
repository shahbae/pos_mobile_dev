class StockMovementModel {
  final int? id;
  final int? materialId;
  final String? type; // "IN" | "OUT" | "ADJUST"
  /// Qty desimal. BE mengirimnya sebagai string ("72", "12.5") sejak stok
  /// bahan jadi decimal(18,4) — dulu dideklarasikan int dan diisi mentah,
  /// sehingga baris pertama sudah melempar TypeError dan seluruh layar
  /// riwayat mutasi bahan gagal dimuat.
  final double quantity;
  final String? referenceType; // "purchase" | "sales" | "manual" | "adjustment"
  final int? referenceId;
  final String? createdAt;

  StockMovementModel({
    this.id,
    this.materialId,
    this.type,
    this.quantity = 0,
    this.referenceType,
    this.referenceId,
    this.createdAt,
  });

  factory StockMovementModel.fromJson(Map<String, dynamic> j) {
    return StockMovementModel(
      id: j['id'],
      materialId: j['material_id'],
      type: j['type'],
      quantity: double.tryParse(j['quantity']?.toString() ?? '') ?? 0,
      referenceType: j['reference_type'],
      referenceId: j['reference_id'],
      createdAt: j['created_at'],
    );
  }
}
