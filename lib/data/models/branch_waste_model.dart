/// Barang cabang yang bisa dibuang (revisi 15 Nov, poin 1): bahan, topping,
/// plastik, sedotan dengan stok lebih dari nol. Minuman jadi tidak termasuk.
class BranchWasteItem {
  /// `material` | `topping` | `plastic` | `sedotan`.
  final String itemType;
  final int id;
  final String name;
  final String unit;

  /// Stok cabang dalam satuan dasar.
  final double qtyOnHand;

  const BranchWasteItem({
    required this.itemType,
    required this.id,
    required this.name,
    required this.unit,
    required this.qtyOnHand,
  });

  factory BranchWasteItem.fromJson(Map<String, dynamic> j) => BranchWasteItem(
        itemType: '${j['item_type'] ?? 'material'}',
        id: j['id'] is num ? (j['id'] as num).toInt() : int.tryParse('${j['id']}') ?? 0,
        name: '${j['name'] ?? ''}',
        unit: '${j['unit'] ?? ''}',
        qtyOnHand: double.tryParse('${j['qty_on_hand'] ?? ''}') ?? 0,
      );

  String get typeLabel => switch (itemType) {
        'topping' => 'Topping',
        'plastic' => 'Plastik',
        'sedotan' => 'Sedotan',
        _ => 'Bahan',
      };
}

/// Hasil `POST /branch-wastes`.
class BranchWasteRecord {
  final int id;
  final String itemName;
  final String unit;
  final String qty;
  final String value;

  const BranchWasteRecord({
    required this.id,
    required this.itemName,
    required this.unit,
    required this.qty,
    required this.value,
  });

  factory BranchWasteRecord.fromJson(Map<String, dynamic> j) => BranchWasteRecord(
        id: j['id'] is num ? (j['id'] as num).toInt() : int.tryParse('${j['id']}') ?? 0,
        itemName: '${j['item_name'] ?? ''}',
        unit: '${j['unit'] ?? ''}',
        qty: '${j['qty'] ?? ''}',
        value: '${j['value'] ?? ''}',
      );
}

/// Pilihan cepat penyebab; teks bebas tetap boleh (server tidak membatasi).
const branchWasteCauses = ['Tumpah', 'Basi', 'Kedaluwarsa', 'Rusak', 'Gagal olah', 'Terkontaminasi'];

/// Batas server: penyebab 100 huruf, keterangan 500 huruf.
const branchWasteCauseMax = 100;
const branchWasteNoteMax = 500;
