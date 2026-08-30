/// Kiriman gudang → outlet (BE Stasiun 4, docs/api-kiriman-gudang-fe.md).
///
/// Berbeda dari permintaan stok yang cuma percakapan, di sini barang benar-benar
/// berpindah. Menekan terima menaikkan stok outlet; menolak mengembalikannya ke
/// gudang. Keduanya tidak bisa dibatalkan.
library;

class Shipment {
  final int id;
  final int branchId;
  final String? branchName;
  final int stockRequestId;

  /// `shipped` | `received` | `rejected` | `cancelled`.
  final String status;

  final String courierName;
  final String courierPhone;
  final String vehiclePlate;
  final String courierNote;

  final String? shipperName;
  final String? shippedAt;
  final String? receivedAt;
  final String? rejectedReason;

  /// Nilai barang yang berpindah, pada harga rata-rata gudang saat dikirim.
  /// Ditampilkan sebagai konteks, bukan sesuatu yang outlet putuskan.
  final double totalCost;

  /// Hanya terisi dari endpoint detail; daftar mengirimnya kosong.
  final List<ShipmentLine> lines;

  Shipment({
    required this.id,
    required this.branchId,
    this.branchName,
    required this.stockRequestId,
    required this.status,
    this.courierName = '',
    this.courierPhone = '',
    this.vehiclePlate = '',
    this.courierNote = '',
    this.shipperName,
    this.shippedAt,
    this.receivedAt,
    this.rejectedReason,
    this.totalCost = 0,
    this.lines = const [],
  });

  /// Sedang di jalan — sudah keluar gudang, belum jadi stok outlet. Ini
  /// satu-satunya status yang menunggu tindakan outlet.
  bool get isOnTheWay => status.toLowerCase() == 'shipped';
  bool get isReceived => status.toLowerCase() == 'received';
  bool get isRejected => status.toLowerCase() == 'rejected';
  bool get isCancelled => status.toLowerCase() == 'cancelled';

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'shipped':
        return 'Menunggu diterima';
      case 'received':
        return 'Sudah diterima';
      case 'rejected':
        return 'Ditolak';
      case 'cancelled':
        return 'Ditarik gudang';
      default:
        return status;
    }
  }

  factory Shipment.fromJson(Map<String, dynamic> j) {
    final rawLines = j['lines'] as List? ?? const [];
    return Shipment(
      id: _toInt(j['id']),
      branchId: _toInt(j['branch_id']),
      branchName: _nestedName(j['branch']),
      stockRequestId: _toInt(j['stock_request_id']),
      status: j['status']?.toString() ?? 'shipped',
      courierName: j['courier_name']?.toString() ?? '',
      courierPhone: j['courier_phone']?.toString() ?? '',
      vehiclePlate: j['vehicle_plate']?.toString() ?? '',
      courierNote: j['courier_note']?.toString() ?? '',
      shipperName: _nestedName(j['shipper']),
      shippedAt: j['shipped_at']?.toString(),
      receivedAt: j['received_at']?.toString(),
      rejectedReason: j['rejected_reason']?.toString(),
      totalCost: _toDouble(j['total_cost']),
      lines: rawLines
          .map((e) => ShipmentLine.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Satu baris barang di surat jalan.
///
/// Tidak ada isian jumlah di layar mana pun: outlet menerima seluruhnya atau
/// menolak seluruhnya, jadi angka ini selalu apa adanya.
class ShipmentLine {
  final int id;
  final String itemType;
  final int itemId;
  final String name;
  final String unit;
  final double qty;
  final double unitCost;
  final double subtotal;

  ShipmentLine({
    required this.id,
    required this.itemType,
    required this.itemId,
    required this.name,
    this.unit = '',
    this.qty = 0,
    this.unitCost = 0,
    this.subtotal = 0,
  });

  String get displayName => name.isNotEmpty ? name : '$itemType #$itemId';

  String get typeLabel {
    switch (itemType) {
      case 'material':
        return 'Bahan';
      case 'topping':
        return 'Topping';
      case 'plastic':
        return 'Plastik';
      case 'sedotan':
        return 'Sedotan';
      default:
        return itemType;
    }
  }

  factory ShipmentLine.fromJson(Map<String, dynamic> j) {
    return ShipmentLine(
      id: _toInt(j['id']),
      itemType: j['item_type']?.toString() ?? '',
      itemId: _toInt(j['item_id']),
      name: j['name']?.toString() ?? '',
      unit: j['unit']?.toString() ?? '',
      qty: _toDouble(j['qty']),
      unitCost: _toDouble(j['unit_cost']),
      subtotal: _toDouble(j['subtotal']),
    );
  }
}

String? _nestedName(dynamic v) {
  if (v is Map && v['name'] != null) {
    final s = v['name'].toString();
    return s.isEmpty ? null : s;
  }
  return null;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

/// Aman untuk num, String desimal ("21500.00"), atau null.
double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
