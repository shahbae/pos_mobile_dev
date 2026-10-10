import 'package:flutter/foundation.dart';

/// Pilihan topping pada sebuah item (gratis maupun berbayar).
class ToppingSelection {
  final int toppingId;
  final int qty;

  /// Harga satu topping yang ditagih. Hanya diisi untuk penjualan offline,
  /// tempat harga di HP menjadi harga resminya; penjualan online selalu
  /// memakai harga server.
  final int? price;

  ToppingSelection({required this.toppingId, required this.qty, this.price});

  Map<String, dynamic> toJson() => {
        'topping_id': toppingId,
        'qty': qty,
        if (price != null) 'price': price,
      };
}

/// Plastik/kemasan yang dipilih untuk seluruh transaksi (top-level, bukan per
/// item). Gratis — tidak menambah total. Hanya pencatatan kemasan + COGS.
class PlasticSelection {
  final int plasticId;
  final int qty;

  PlasticSelection({required this.plasticId, required this.qty});

  Map<String, dynamic> toJson() => {
        'plastic_id': plasticId,
        'qty': qty,
      };
}

/// Sedotan yang dipilih untuk seluruh transaksi (top-level, bukan per item).
/// Gratis — tidak menambah total. Hanya pencatatan sedotan + COGS.
class SedotanSelection {
  final int sedotanId;
  final int qty;

  SedotanSelection({required this.sedotanId, required this.qty});

  Map<String, dynamic> toJson() => {
        'sedotan_id': sedotanId,
        'qty': qty,
      };
}

class ProductTransactionRequest {
  final List<TransactionItem> items;
  final List<PromoFreeItem> promoFreeItems;
  final List<PlasticSelection> plastics; // kemasan gratis (opsional)
  final List<SedotanSelection> sedotans; // sedotan gratis (opsional)
  final String paymentMethod; // CASH | TRANSFER | QRIS | DEBIT | CREDIT | EWALLET
  final int paid; // integer rupiah
  final int discount; // integer rupiah
  final String? paymentRef; // nomor referensi untuk non-cash
  final String? customerName; // atas nama (free text), opsional
  final String? idempotencyKey;

  ProductTransactionRequest({
    required this.items,
    this.promoFreeItems = const [],
    this.plastics = const [],
    this.sedotans = const [],
    required this.paymentMethod,
    required this.paid,
    this.discount = 0,
    this.paymentRef,
    this.customerName,
    this.idempotencyKey,
  });

  /// [forQris] = alur QRIS dinamis: `payment_ref` tidak dikirim (nomor ref
  /// dibuat gateway). `paid` TETAP dikirim (= total) — BE memvalidasinya.
  Map<String, dynamic> toJson({bool forQris = false}) {
    return {
      'payment_method': paymentMethod,
      if (!forQris) 'payment_ref': paymentRef,
      'paid': paid,
      'discount': discount,
      'items': items.map((i) => i.toJson()).toList(),
      if (promoFreeItems.isNotEmpty)
        'promo_free_items': promoFreeItems.map((p) => p.toJson()).toList(),
      if (plastics.isNotEmpty) 'plastics': plastics.map((p) => p.toJson()).toList(),
      if (sedotans.isNotEmpty) 'sedotans': sedotans.map((s) => s.toJson()).toList(),
      if (customerName != null && customerName!.isNotEmpty) 'customer_name': customerName,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    };
  }
}

class TransactionItem {
  final int productId;
  final int? variantId; // null = pakai harga & resep produk (behavior lama)
  final int quantity;
  /// Berapa gelas dari [quantity] yang dituang ke tumbler bawaan pembeli. BE
  /// memakai ini untuk tidak memotong cup & sealer sebanyak itu. Sedotan tetap
  /// keluar. Tidak boleh melebihi [quantity].
  final int tumblerQty;
  final List<ToppingSelection> freeToppings; // include di harga, tidak menambah subtotal
  final List<ToppingSelection> extraToppings; // berbayar

  /// Harga satuan yang ditagih. Hanya diisi untuk penjualan offline.
  final int? unitPrice;

  TransactionItem({
    required this.productId,
    this.variantId,
    required this.quantity,
    this.tumblerQty = 0,
    this.freeToppings = const [],
    this.extraToppings = const [],
    this.unitPrice,
  });

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      if (variantId != null) 'variant_id': variantId,
      'qty': quantity,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (tumblerQty > 0) 'tumbler_qty': tumblerQty,
      if (freeToppings.isNotEmpty)
        'free_toppings': freeToppings.map((t) => t.toJson()).toList(),
      if (extraToppings.isNotEmpty)
        'extra_toppings': extraToppings.map((t) => t.toJson()).toList(),
    };
  }
}

/// Item yang digratiskan lewat promo. Kasir menentukan item mana yang gratis.
class PromoFreeItem {
  final int promoId;
  final int productId;
  final int? variantId; // null = produk tanpa variant
  final int qty;
  final List<ToppingSelection> extraToppings; // extra topping pada item gratis

  PromoFreeItem({
    required this.promoId,
    required this.productId,
    this.variantId,
    required this.qty,
    this.extraToppings = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'promo_id': promoId,
      'product_id': productId,
      if (variantId != null) 'variant_id': variantId,
      'qty': qty,
      'extra_toppings': extraToppings.map((t) => t.toJson()).toList(),
    };
  }
}

/// Gagal membuat transaksi. [toString] mengembalikan pesannya saja supaya bisa
/// langsung ditampilkan ke kasir.
class TransactionSubmitException implements Exception {
  final String message;

  /// true → server menjawab dan menolak (4xx): transaksi pasti TIDAK tercatat.
  /// false → tak ada jawaban atau server galat (5xx): transaksi bisa saja sudah
  /// tercatat, jadi percobaan berikutnya wajib memakai idempotency key yang sama.
  final bool rejected;

  /// true → tidak ada jawaban sama sekali (timeout, koneksi putus): server tak
  /// terjangkau. Beda dari 5xx, yang berarti server hidup tetapi gagal.
  final bool unreachable;

  /// Status HTTP jawaban server; null bila tidak ada jawaban.
  final int? statusCode;

  const TransactionSubmitException(
    this.message, {
    required this.rejected,
    this.unreachable = false,
    this.statusCode,
  });

  /// true → server menolak ISI permintaannya (400, 409, 422): mengirim ulang
  /// hal yang sama tidak akan pernah berhasil. Penolakan lain — sesi habis
  /// (401), tidak berwenang (403), terlalu sering (429) — bukan soal isinya
  /// dan bisa berhasil nanti.
  bool get payloadRejected => statusCode == 400 || statusCode == 409 || statusCode == 422;

  @override
  String toString() => message;
}

class ProductTransactionResponse {
  final String invoiceNumber;
  final int saleId;
  final bool success;

  /// Metode bayar yang tercatat di server (huruf kecil), null bila tidak ada di
  /// response. Bisa beda dari yang baru dipilih kasir: percobaan ulang dengan
  /// key yang sama dibalas dengan transaksi yang SUDAH tercatat.
  final String? paymentMethod;

  /// Nomor antrean yang diberikan server; 0 bila tidak ada di response.
  final int queueNo;

  ProductTransactionResponse({
    required this.invoiceNumber,
    required this.saleId,
    required this.success,
    this.paymentMethod,
    this.queueNo = 0,
  });

  factory ProductTransactionResponse.fromJson(Map<String, dynamic> json) {
    debugPrint('[TransactionModel] Parsing JSON: $json');
    final data = json['data'] ?? json; // Fallback to root if data is missing
    final invoice = data['invoice_number'] ??
        data['invoice_no'] ??
        data['invoiceNumber'] ??
        data['invoiceNo'] ??
        data['invoice'] ??
        data['ref'] ??
        json['invoice_number'] ??
        json['invoice_no'] ??
        json['invoiceNumber'] ??
        json['invoiceNo'] ??
        json['invoice'] ??
        json['ref'] ??
        '';
    debugPrint('[TransactionModel] Extracted invoice: $invoice');

    return ProductTransactionResponse(
      invoiceNumber: invoice.toString(),
      saleId: data['sale_id'] ?? json['sale_id'] ?? 0,
      success: json['success'] ?? false,
      paymentMethod: data['payment_method']?.toString(),
      queueNo: (data['queue_no'] as num?)?.toInt() ?? 0,
    );
  }
}
