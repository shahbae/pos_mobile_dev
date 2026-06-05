/// Model nota/struk transaksi.
///
/// Dipakai untuk cetak nota, baik setelah transaksi berhasil maupun dari
/// riwayat transaksi. Sumber data: GET /transactions/{invoice_no}
class Receipt {
  final String invoiceNo;
  final DateTime? createdAt;
  final String cashierName;
  final List<ReceiptItem> items;
  final num subtotal;
  final num discount;
  final num tax;
  final num total;
  final num paid;
  final num change;
  final String paymentMethod;
  final String? paymentRef;
  final ReceiptStore store;

  Receipt({
    required this.invoiceNo,
    required this.createdAt,
    required this.cashierName,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.paid,
    required this.change,
    required this.paymentMethod,
    required this.paymentRef,
    required this.store,
  });

  factory Receipt.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map) ? json['data'] as Map<String, dynamic> : json;
    final List<dynamic> itemsJson = data['items'] ?? [];

    return Receipt(
      invoiceNo: data['invoice_no']?.toString() ?? '',
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
      cashierName: data['cashier_name']?.toString() ?? '-',
      items: itemsJson.map((i) => ReceiptItem.fromJson(i as Map<String, dynamic>)).toList(),
      subtotal: _num(data['subtotal']),
      discount: _num(data['discount']),
      tax: _num(data['tax']),
      total: _num(data['total']),
      paid: _num(data['paid']),
      change: _num(data['change']),
      paymentMethod: data['payment_method']?.toString() ?? '-',
      paymentRef: data['payment_ref']?.toString(),
      store: ReceiptStore.fromJson((data['store'] as Map<String, dynamic>?) ?? const {}),
    );
  }
}

class ReceiptItem {
  final String name;
  final int qty;
  final num price;

  ReceiptItem({required this.name, required this.qty, required this.price});

  num get lineTotal => price * qty;

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      name: json['name']?.toString() ?? '',
      qty: _num(json['qty']).toInt(),
      price: _num(json['price']),
    );
  }
}

class ReceiptStore {
  final String name;
  final String address;
  final String footerNote;

  ReceiptStore({required this.name, required this.address, required this.footerNote});

  factory ReceiptStore.fromJson(Map<String, dynamic> json) {
    return ReceiptStore(
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      footerNote: json['footer_note']?.toString() ?? '',
    );
  }
}

num _num(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  return num.tryParse(v.toString()) ?? 0;
}
