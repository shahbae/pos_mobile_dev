/// Model nota/struk transaksi.
///
/// Dipakai untuk cetak nota, baik setelah transaksi berhasil maupun dari
/// riwayat transaksi. Sumber data: GET /transactions/{invoice_no}
class Receipt {
  final String invoiceNo;
  final DateTime? createdAt;
  final String cashierName;
  final String? customerName;
  final List<ReceiptItem> items;
  final List<ReceiptPlastic> plastics;
  final List<ReceiptSedotan> sedotans;
  final num subtotal;
  final num discount;
  final num promoDiscount;
  final List<ReceiptPromo> promos;
  final num tax;
  final num total;
  final num paid;
  final num change;
  final String paymentMethod;
  final String? paymentRef;

  /// Estimasi waktu pembuatan dalam menit, sudah dibulatkan ke kelipatan 5 oleh
  /// BE. `0` = produknya belum diisi waktu pembuatan → jangan cetak apa pun.
  final int estimatedPrepMinutes;

  /// Nomor antrean yang dipanggil ke pelanggan, mulai dari 1 tiap shift.
  /// 0 = belum punya nomor (QRIS belum lunas) atau transaksi lama sebelum
  /// fitur ini ada — barisnya tidak dicetak.
  final int queueNo;

  /// Jam janji siap, dibekukan saat pembayaran (tidak dihitung ulang saat cetak
  /// ulang). Null = tidak ada estimasi.
  final DateTime? estimatedReadyAt;

  final ReceiptStore store;

  Receipt({
    required this.invoiceNo,
    required this.createdAt,
    required this.cashierName,
    this.customerName,
    required this.items,
    this.plastics = const [],
    this.sedotans = const [],
    required this.subtotal,
    required this.discount,
    this.promoDiscount = 0,
    this.promos = const [],
    required this.tax,
    required this.total,
    required this.paid,
    required this.change,
    required this.paymentMethod,
    required this.paymentRef,
    this.estimatedPrepMinutes = 0,
    this.queueNo = 0,
    this.estimatedReadyAt,
    required this.store,
  });

  /// Pembayaran tunai. BE bisa mengirim 'cash'/'CASH', UI lama kirim 'tunai'.
  bool get isCashPayment {
    final m = paymentMethod.trim().toLowerCase();
    return m == 'cash' || m == 'tunai';
  }

  /// Baris estimasi hanya dicetak bila kedua nilainya terisi. Jangan pernah
  /// menampilkan "0 menit" / "siap sekarang" — itu artinya produknya memang
  /// belum diisi waktu pembuatan, bukan pesanannya instan.
  bool get hasEstimate => estimatedReadyAt != null && estimatedPrepMinutes > 0;

  bool get hasQueueNo => queueNo > 0;

  factory Receipt.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map) ? json['data'] as Map<String, dynamic> : json;
    final List<dynamic> itemsJson = data['items'] ?? [];
    final List<dynamic> promosJson = data['promos'] ?? [];
    final List<dynamic> plasticsJson = data['plastics'] ?? [];
    final List<dynamic> sedotansJson = data['sedotans'] ?? [];

    return Receipt(
      invoiceNo: data['invoice_no']?.toString() ?? '',
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
      cashierName: data['cashier_name']?.toString() ?? '-',
      customerName: (data['customer_name']?.toString().trim().isEmpty ?? true)
          ? null
          : data['customer_name'].toString(),
      items: itemsJson.map((i) => ReceiptItem.fromJson(i as Map<String, dynamic>)).toList(),
      plastics: plasticsJson.map((p) => ReceiptPlastic.fromJson(p as Map<String, dynamic>)).toList(),
      sedotans: sedotansJson.map((s) => ReceiptSedotan.fromJson(s as Map<String, dynamic>)).toList(),
      subtotal: _num(data['subtotal']),
      discount: _num(data['discount']),
      promoDiscount: _num(data['promo_discount']),
      promos: promosJson.map((p) => ReceiptPromo.fromJson(p as Map<String, dynamic>)).toList(),
      tax: _num(data['tax']),
      total: _num(data['total']),
      paid: _num(data['paid']),
      change: _num(data['change']),
      paymentMethod: data['payment_method']?.toString() ?? '-',
      paymentRef: data['payment_ref']?.toString(),
      estimatedPrepMinutes: _num(data['estimated_prep_minutes']).toInt(),
      queueNo: _num(data['queue_no']).toInt(),
      estimatedReadyAt:
          DateTime.tryParse(data['estimated_ready_at']?.toString() ?? ''),
      store: ReceiptStore.fromJson((data['store'] as Map<String, dynamic>?) ?? const {}),
    );
  }
}

class ReceiptItem {
  final String name;
  final String? variantName; // null bila item tanpa variant
  final int qty;
  final num price;
  final List<ReceiptTopping> toppings;

  ReceiptItem({
    required this.name,
    this.variantName,
    required this.qty,
    required this.price,
    this.toppings = const [],
  });

  num get lineTotal => price * qty;

  /// Nama tampilan: "Produk - Variant" bila ada variant.
  String get displayName =>
      (variantName != null && variantName!.isNotEmpty) ? '$name - $variantName' : name;

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    final List<dynamic> toppingsJson = json['toppings'] ?? [];
    final variant = json['variant_name']?.toString();
    return ReceiptItem(
      name: json['name']?.toString() ?? '',
      variantName: (variant == null || variant.trim().isEmpty) ? null : variant,
      qty: _num(json['qty']).toInt(),
      price: _num(json['price']),
      toppings: toppingsJson.map((t) => ReceiptTopping.fromJson(t as Map<String, dynamic>)).toList(),
    );
  }
}

class ReceiptTopping {
  final String name;
  final int qty;
  final num price; // 0 = gratis, >0 = berbayar

  ReceiptTopping({required this.name, required this.qty, required this.price});

  bool get isFree => price <= 0;
  num get lineTotal => price * qty;

  factory ReceiptTopping.fromJson(Map<String, dynamic> json) {
    return ReceiptTopping(
      name: json['name']?.toString() ?? '',
      qty: _num(json['qty']).toInt(),
      price: _num(json['price']),
    );
  }
}

/// Kemasan plastik pada struk. Gratis — tanpa harga.
class ReceiptPlastic {
  final String name;
  final int qty;

  ReceiptPlastic({required this.name, required this.qty});

  factory ReceiptPlastic.fromJson(Map<String, dynamic> json) {
    return ReceiptPlastic(
      name: json['name']?.toString() ?? '',
      qty: _num(json['qty']).toInt(),
    );
  }
}

/// Sedotan pada struk. Gratis — tanpa harga.
class ReceiptSedotan {
  final String name;
  final int qty;

  ReceiptSedotan({required this.name, required this.qty});

  factory ReceiptSedotan.fromJson(Map<String, dynamic> json) {
    return ReceiptSedotan(
      name: json['name']?.toString() ?? '',
      qty: _num(json['qty']).toInt(),
    );
  }
}

class ReceiptPromo {
  final String name;
  final num discount;

  ReceiptPromo({required this.name, required this.discount});

  factory ReceiptPromo.fromJson(Map<String, dynamic> json) {
    return ReceiptPromo(
      name: json['name']?.toString() ?? '',
      discount: _num(json['discount']),
    );
  }
}

class ReceiptStore {
  final String name;
  final String address;
  final String footerNote;

  /// Catatan komplain (revisi BE 2026-07-07). Di struk selalu string —
  /// kosong ("") bila belum diisi. Render barisnya hanya bila tidak kosong.
  final String complaintNote;

  ReceiptStore({
    required this.name,
    required this.address,
    required this.footerNote,
    this.complaintNote = '',
  });

  factory ReceiptStore.fromJson(Map<String, dynamic> json) {
    return ReceiptStore(
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      footerNote: json['footer_note']?.toString() ?? '',
      complaintNote: json['complaint_note']?.toString() ?? '',
    );
  }
}

num _num(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  return num.tryParse(v.toString()) ?? 0;
}
