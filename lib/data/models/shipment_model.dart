/// Kiriman gudang → outlet (BE Stasiun 4, docs/api-kiriman-gudang-fe.md).
///
/// Berbeda dari permintaan stok yang cuma percakapan, di sini barang benar-benar
/// berpindah. Menekan terima menaikkan stok outlet; menolak mengembalikannya ke
/// gudang. Keduanya tidak bisa dibatalkan.
library;

import 'dart:typed_data';

import 'package:pos_mobile/data/models/stock_pack_model.dart';

class Shipment {
  final int id;
  final int branchId;
  final String? branchName;
  final int stockRequestId;

  /// `shipped` | `received` | `rejected` | `cancelled`.
  final String status;

  // Tidak ada data kurir: kolomnya sudah dibuang dari surat jalan di BE, jadi
  // tidak ada yang bisa dibaca maupun ditampilkan. `shipperName` di bawah
  // sudah menjawab "siapa yang melepas barangnya".
  final String? shipperName;
  final String? shippedAt;
  final String? receivedAt;
  final String? rejectedReason;

  /// Nilai barang yang berpindah, pada harga rata-rata gudang saat dikirim.
  /// Ditampilkan sebagai konteks, bukan sesuatu yang outlet putuskan.
  final double totalCost;

  /// Naik tiap kali gudang mengubah isi kiriman sebelum diterima (revisi 17
  /// Okt 2026). Dikirim balik saat menerima: server menolak bila isi yang
  /// dilihat di layar ini sudah bukan isi yang sekarang.
  final int revision;
  final String? editReason;
  final String? editedAt;

  /// Hanya terisi dari endpoint detail; daftar mengirimnya kosong.
  final List<ShipmentLine> lines;

  Shipment({
    required this.id,
    required this.branchId,
    this.branchName,
    required this.stockRequestId,
    required this.status,
    this.shipperName,
    this.shippedAt,
    this.receivedAt,
    this.rejectedReason,
    this.totalCost = 0,
    this.revision = 0,
    this.editReason,
    this.editedAt,
    this.lines = const [],
  });

  /// Isinya pernah diubah gudang setelah berangkat.
  bool get wasEdited => revision > 0;

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
      shipperName: _nestedName(j['shipper']),
      shippedAt: j['shipped_at']?.toString(),
      receivedAt: j['received_at']?.toString(),
      rejectedReason: j['rejected_reason']?.toString(),
      totalCost: _toDouble(j['total_cost']),
      revision: _toInt(j['revision']),
      editReason: (j['edit_reason']?.toString().isNotEmpty ?? false)
          ? j['edit_reason'].toString()
          : null,
      editedAt: j['edited_at']?.toString(),
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

  /// [qty] dalam kemasan pertama barang ini, null bila tak punya template
  /// (atau BE lama yang belum mengirimnya).
  final StockPack? pack;

  /// Bagian yang rusak / kedaluwarsa saat diterima (Tahap 7, PRD-C2), dalam
  /// satuan dasar. Tidak masuk stok outlet.
  final double damagedQty;
  final double expiredQty;
  final String? damagePhotoUrl;

  /// Jumlah yang diketik leader saat menerima (revisi KPI 11 Nov, L2.B),
  /// satuan dasar. Null untuk kiriman yang belum diterima atau BE lama.
  final double? receivedQty;

  /// `pending` = berbeda dari surat jalan lebih dari batas, menunggu SPV;
  /// `input_error` = SPV memutus salah input; `real_diff` = memang selisih;
  /// kosong = sama.
  final String receiveDiffStatus;

  ShipmentLine({
    required this.id,
    required this.itemType,
    required this.itemId,
    required this.name,
    this.unit = '',
    this.qty = 0,
    this.unitCost = 0,
    this.subtotal = 0,
    this.pack,
    this.damagedQty = 0,
    this.expiredQty = 0,
    this.damagePhotoUrl,
    this.receivedQty,
    this.receiveDiffStatus = '',
  });

  bool get hasDamage => damagedQty > 0 || expiredQty > 0;

  /// Jumlah diterima berbeda dari yang dikirim.
  bool get receivedDiffers => receivedQty != null && (receivedQty! - qty).abs() > 1e-6;

  String get receiveDiffLabel {
    switch (receiveDiffStatus) {
      case 'pending':
        return 'Selisih menunggu SPV';
      case 'input_error':
        return 'SPV: salah input';
      case 'real_diff':
        return 'SPV: memang selisih';
      default:
        return '';
    }
  }

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
      pack: StockPack.tryFrom(j['pack']),
      damagedQty: _toDouble(j['damaged_qty']),
      expiredQty: _toDouble(j['expired_qty']),
      damagePhotoUrl: (j['damage_photo_url']?.toString().isNotEmpty ?? false) ? j['damage_photo_url'].toString() : null,
      receivedQty: j['received_qty'] == null ? null : _toDouble(j['received_qty']),
      receiveDiffStatus: j['receive_diff_status']?.toString() ?? '',
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

// ---------------------------------------------------------------- terima

/// Isian satu baris saat menerima: jumlah yang benar-benar diterima (revisi
/// KPI 11 Nov, L2.B) dan bagian yang rusak/kedaluwarsa (Tahap 7, PRD-C2).
///
/// Diisi dalam KEMASAN bila barangnya punya kemasan ("2 botol"), selain itu
/// dalam satuan dasar. Yang dikirim ke server selalu satuan dasar.
class ReceiveLineInput {
  final ShipmentLine line;

  /// Jumlah diterima yang diketik leader, satuan isian. Null = belum diisi
  /// (wajib sebelum Terima).
  final double? received;
  final double damaged;
  final double expired;

  /// Foto bukti, sudah dibaca ke memori. Wajib bila ada yang rusak/expired.
  final Uint8List? photo;

  const ReceiveLineInput({required this.line, this.received, this.damaged = 0, this.expired = 0, this.photo});

  ReceiveLineInput copyWith({
    double? received,
    bool clearReceived = false,
    double? damaged,
    double? expired,
    Uint8List? photo,
    bool clearPhoto = false,
  }) =>
      ReceiveLineInput(
        line: line,
        received: clearReceived ? null : (received ?? this.received),
        damaged: damaged ?? this.damaged,
        expired: expired ?? this.expired,
        photo: clearPhoto ? null : (photo ?? this.photo),
      );

  /// Isi satu satuan isian dalam satuan dasar: isi kemasan, atau 1.
  double get factor {
    final b = line.pack?.baseQty ?? 0;
    return b > 0 ? b : 1;
  }

  /// Nama satuan isian ("botol", "ml").
  String get inputUnit {
    final n = line.pack?.name.trim() ?? '';
    return (line.pack?.baseQty ?? 0) > 0 && n.isNotEmpty ? n.replaceFirst(RegExp(r'^1\s*(?=[^\d\s])'), '') : line.unit;
  }

  /// Jumlah kiriman dalam satuan isian.
  double get shippedInInput => line.qty / factor;

  double get damagedBase => damaged * factor;
  double get expiredBase => expired * factor;
  bool get hasDamage => damaged > 0 || expired > 0;

  /// Jumlah diterima dalam satuan dasar; belum diisi = dianggap sama dengan
  /// yang dikirim (hanya untuk tampilan; Terima menahannya).
  double get receivedBase => received == null ? line.qty : received! * factor;

  /// Diketik dan berbeda dari surat jalan.
  bool get differs => received != null && (receivedBase - line.qty).abs() > 1e-6;

  /// Yang masuk stok outlet, satuan dasar.
  double get acceptedBase {
    final v = receivedBase - damagedBase - expiredBase;
    return v < 0 ? 0 : v;
  }

  bool get exceeds => damagedBase + expiredBase > receivedBase + 1e-6;
  bool get needsPhoto => hasDamage && photo == null;
}

/// Apa yang menahan Terima, sebagai kalimat.
List<String> receiveProblems(List<ReceiveLineInput> lines) => [
  for (final l in lines)
    if (l.received == null)
      '${l.line.displayName}: isi jumlah yang diterima.'
    else if (l.received! < 0 || l.damaged < 0 || l.expired < 0)
      '${l.line.displayName}: jumlah tidak boleh minus.'
    else if (l.exceeds)
      '${l.line.displayName}: rusak + kedaluwarsa melebihi yang diterima.'
    else if (l.needsPhoto)
      '${l.line.displayName}: ambil foto barang yang rusak/kedaluwarsa.',
];

/// Angka satuan dasar sebagai teks desimal untuk server ("2", "1.5").
String receiveQtyParam(double v) {
  final r = (v * 10000).roundToDouble() / 10000;
  return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();
}
