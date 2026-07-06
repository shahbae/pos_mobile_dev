import 'stock_pack_model.dart';

/// Saldo stok sebuah plastik per cabang. Qty bisa desimal.
class PlasticStock {
  final int id;
  final int plasticId;
  final int? branchId;
  final String name;
  final String unit;
  final double qty;

  /// Jumlah stok masuk (movement IN) hari ini. BE kirim string desimal.
  final double incomingToday;

  /// Konversi qty on-hand ke kemasan (PurchaseTemplate). Kosong bila tak ada.
  final List<StockPack> packs;

  PlasticStock({
    required this.id,
    required this.plasticId,
    this.branchId,
    this.name = '',
    this.unit = '',
    this.qty = 0,
    this.incomingToday = 0,
    this.packs = const [],
  });

  factory PlasticStock.fromJson(Map<String, dynamic> j) {
    final p = j['plastic'] as Map<String, dynamic>?;
    return PlasticStock(
      id: j['id'],
      plasticId: j['plastic_id'] ?? p?['id'],
      branchId: j['branch_id'],
      name: j['name']?.toString() ??
          p?['name']?.toString() ??
          j['plastic_name']?.toString() ??
          'Plastik',
      unit: j['unit']?.toString() ?? p?['unit']?.toString() ?? '',
      qty: double.tryParse(j['qty']?.toString() ?? '') ?? 0,
      incomingToday: double.tryParse(j['incoming_today']?.toString() ?? '') ?? 0,
      packs: StockPack.listFrom(j['packs']),
    );
  }
}
