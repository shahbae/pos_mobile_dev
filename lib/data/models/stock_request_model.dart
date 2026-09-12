/// Permintaan stok outlet ke gudang pusat (BE Stasiun 3,
/// docs/api-permintaan-stok-fe.md).
///
/// Outlet mengajukan dari app ini; gudang meng-acc dari web admin. Tidak ada
/// endpoint di sini yang menggerakkan stok — barang baru berpindah saat kiriman
/// diterima, dan itu belum ada (Stasiun 4).
library;

class StockRequest {
  final int id;
  final int branchId;
  final String? branchName;
  final int requestedBy;
  final String? requesterName;

  /// `submitted` | `approved` | `rejected` | `cancelled` | `fulfilled`.
  final String status;
  final String? rejectedReason;
  final String note;
  final String? createdAt;
  final String? approvedAt;

  /// Baris permintaan yang sudah diperkaya BE (nama, satuan, stok gudang).
  /// Hanya terisi dari endpoint detail; daftar mengirimnya kosong.
  final List<StockRequestLine> lines;

  StockRequest({
    required this.id,
    required this.branchId,
    this.branchName,
    required this.requestedBy,
    this.requesterName,
    required this.status,
    this.rejectedReason,
    this.note = '',
    this.createdAt,
    this.approvedAt,
    this.lines = const [],
  });

  bool get isSubmitted => status.toLowerCase() == 'submitted';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isRejected => status.toLowerCase() == 'rejected';

  /// Hanya permintaan yang belum diputuskan yang masih boleh diubah/dibatalkan.
  /// Setelah di-acc jumlahnya terkunci — kirimannya mungkin sudah disiapkan.
  bool get isEditable => isSubmitted;

  /// Sudah di-acc tapi ada baris yang dipotong atau ditolak. Perlu ditonjolkan:
  /// outlet gampang mengira permintaannya lolos utuh.
  bool get hasCut =>
      isApproved && lines.any((l) => l.qtyApproved < l.qtyRequested);

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'submitted':
        return 'Menunggu gudang';
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      case 'cancelled':
        return 'Dibatalkan';
      case 'fulfilled':
        return 'Sudah diterima';
      default:
        return status;
    }
  }

  factory StockRequest.fromJson(Map<String, dynamic> j) {
    final rawLines = j['lines'] as List? ?? const [];
    return StockRequest(
      id: _toInt(j['id']),
      branchId: _toInt(j['branch_id']),
      branchName: _nestedName(j['branch']),
      requestedBy: _toInt(j['requested_by']),
      requesterName: _nestedName(j['requester']),
      status: j['status']?.toString() ?? 'submitted',
      rejectedReason: j['rejected_reason']?.toString(),
      note: j['note']?.toString() ?? '',
      createdAt: j['created_at']?.toString(),
      approvedAt: j['approved_at']?.toString(),
      lines: rawLines
          .map((e) => StockRequestLine.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Satu baris permintaan. Dua angka hidup berdampingan di sini dan keduanya
/// perlu: yang kemasan adalah yang diketik orang, yang dasar adalah yang akan
/// benar-benar dipindahkan.
class StockRequestLine {
  /// Id BARIS, bukan id barang. Ini yang dipakai gudang saat acc.
  final int id;
  final String itemType;
  final int itemId;
  final String name;
  final String unit;
  final int templateId;
  final String templateName;

  /// Isi satu kemasan dalam satuan dasar ("1 pack = 5000 ml").
  final double baseQty;
  final double packQty;
  final double qtyRequested;
  final double packQtyApproved;
  final double qtyApproved;

  /// Stok gudang saat endpoint dipanggil. Dibaca ulang tiap kali, jangan
  /// di-cache.
  final double warehouseQty;

  StockRequestLine({
    required this.id,
    required this.itemType,
    required this.itemId,
    required this.name,
    this.unit = '',
    required this.templateId,
    this.templateName = '',
    this.baseQty = 0,
    this.packQty = 0,
    this.qtyRequested = 0,
    this.packQtyApproved = 0,
    this.qtyApproved = 0,
    this.warehouseQty = 0,
  });

  String get displayName => name.isNotEmpty ? name : '$itemType #$itemId';

  factory StockRequestLine.fromJson(Map<String, dynamic> j) {
    return StockRequestLine(
      id: _toInt(j['id']),
      itemType: j['item_type']?.toString() ?? '',
      itemId: _toInt(j['item_id']),
      name: j['name']?.toString() ?? '',
      unit: j['unit']?.toString() ?? '',
      templateId: _toInt(j['template_id']),
      templateName: j['template_name']?.toString() ?? '',
      baseQty: _toDouble(j['base_qty']),
      packQty: _toDouble(j['pack_qty']),
      qtyRequested: _toDouble(j['qty_requested']),
      packQtyApproved: _toDouble(j['pack_qty_approved']),
      qtyApproved: _toDouble(j['qty_approved']),
      warehouseQty: _toDouble(j['warehouse_qty']),
    );
  }
}

/// Barang yang boleh diminta (GET /stock-requests/requestable-items).
///
/// Daftarnya ditentukan BE dan bisa berubah tanpa rilis app — **jangan disusun
/// sendiri** dari /materials, /toppings, dan seterusnya. Bahan mentah tidak
/// pernah muncul di sini: gudang yang mengolahnya.
class RequestableItem {
  final String itemType;
  final int itemId;
  final String name;
  final String unit;

  /// Stok gudang, buat konteks. Tidak membatasi jumlah yang boleh diminta —
  /// gudang bisa memproduksi dulu sebelum mengirim.
  final double warehouseQty;

  /// Pilihan kemasan. Selalu berisi minimal satu: BE menyembunyikan barang yang
  /// belum punya kemasan, karena tidak ada cara menyebut jumlahnya.
  final List<RequestableTemplate> templates;

  RequestableItem({
    required this.itemType,
    required this.itemId,
    required this.name,
    this.unit = '',
    this.warehouseQty = 0,
    this.templates = const [],
  });

  /// Kunci unik lintas tipe untuk state form (mis. "material:33").
  String get key => '$itemType:$itemId';

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

  factory RequestableItem.fromJson(Map<String, dynamic> j) {
    final raw = j['templates'] as List? ?? const [];
    return RequestableItem(
      itemType: j['item_type']?.toString() ?? '',
      itemId: _toInt(j['item_id']),
      name: j['name']?.toString() ?? '',
      unit: j['unit']?.toString() ?? '',
      warehouseQty: _toDouble(j['warehouse_qty']),
      templates: raw
          .map((e) => RequestableTemplate.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RequestableTemplate {
  final int id;
  final String name;
  final double baseQty;

  RequestableTemplate({
    required this.id,
    required this.name,
    this.baseQty = 0,
  });

  factory RequestableTemplate.fromJson(Map<String, dynamic> j) {
    return RequestableTemplate(
      id: _toInt(j['id']),
      name: j['name']?.toString() ?? '',
      baseQty: _toDouble(j['base_qty']),
    );
  }
}

/// BE mem-preload `branch` & `requester` sebagai objek; ambil namanya saja.
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

/// Aman untuk num, String desimal ("10000.0000"), atau null — BE mengirim
/// desimal sebagai teks supaya pecahan tidak dibulatkan di perjalanan.
double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
