import 'stock_pack_model.dart';

/// Saldo stok sebuah sedotan per cabang. Qty bisa desimal.
class SedotanStock {
  final int id;
  final int sedotanId;
  final int? branchId;
  final String name;
  final String unit;
  final double qty;

  /// Jumlah stok masuk (movement IN) hari ini. BE kirim string desimal.
  final double incomingToday;

  /// Konversi qty on-hand ke kemasan (PurchaseTemplate). Kosong bila tak ada.
  final List<StockPack> packs;

  SedotanStock({
    required this.id,
    required this.sedotanId,
    this.branchId,
    this.name = '',
    this.unit = '',
    this.qty = 0,
    this.incomingToday = 0,
    this.packs = const [],
  });

  factory SedotanStock.fromJson(Map<String, dynamic> j) {
    final s = j['sedotan'] as Map<String, dynamic>?;
    return SedotanStock(
      id: j['id'],
      sedotanId: j['sedotan_id'] ?? s?['id'],
      branchId: j['branch_id'],
      name: j['name']?.toString() ??
          s?['name']?.toString() ??
          j['sedotan_name']?.toString() ??
          'Sedotan',
      unit: j['unit']?.toString() ?? s?['unit']?.toString() ?? '',
      qty: double.tryParse(j['qty']?.toString() ?? '') ?? 0,
      incomingToday: double.tryParse(j['incoming_today']?.toString() ?? '') ?? 0,
      packs: StockPack.listFrom(j['packs']),
    );
  }
}
