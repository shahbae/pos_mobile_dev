/// Model layar monitoring pesanan (KDS).
///
/// Bentuk JSON di sini HARUS sama persis dengan `services.KitchenOrder` di BE
/// (`internal/services/kitchen_service.go`) — payload frame SSE dan response
/// snapshot `GET /kds/orders` memakai struct yang sama, jadi parser ini dipakai
/// untuk keduanya. Kalau salah satu berubah, keduanya ikut berubah.

/// Status dapur. Alur: queued → preparing → ready → served.
/// `served` membuat kartu hilang dari layar.
const kitchenStatusQueued = 'queued';
const kitchenStatusPreparing = 'preparing';
const kitchenStatusReady = 'ready';
const kitchenStatusServed = 'served';

/// Status yang masih tampil di layar (dipakai sebagai filter snapshot).
const kitchenActiveStatuses = [
  kitchenStatusQueued,
  kitchenStatusPreparing,
  kitchenStatusReady,
];

/// Status berikutnya dalam alur, atau null bila sudah di ujung.
String? nextKitchenStatus(String status) {
  switch (status) {
    case kitchenStatusQueued:
      return kitchenStatusPreparing;
    case kitchenStatusPreparing:
      return kitchenStatusReady;
    case kitchenStatusReady:
      return kitchenStatusServed;
    default:
      return null;
  }
}

/// Label tombol aksi yang memindahkan pesanan ke status berikutnya.
String? kitchenActionLabel(String status) {
  switch (status) {
    case kitchenStatusQueued:
      return 'Mulai Buat';
    case kitchenStatusPreparing:
      return 'Siap';
    case kitchenStatusReady:
      return 'Diserahkan';
    default:
      return null;
  }
}

/// Label status untuk badge di kartu.
String kitchenStatusLabel(String status) {
  switch (status) {
    case kitchenStatusQueued:
      return 'Antre';
    case kitchenStatusPreparing:
      return 'Dibuat';
    case kitchenStatusReady:
      return 'Siap';
    case kitchenStatusServed:
      return 'Selesai';
    default:
      return status;
  }
}

/// Satu baris item pada kartu dapur.
class KitchenOrderItem {
  final int id;
  final String name;

  /// Nama varian (mis. "Large"). Kosong bila produk tanpa varian.
  final String variantName;
  final int qty;

  /// Topping sudah dirakit BE jadi label siap tampil, mis. "Boba x2".
  final List<String> toppings;

  const KitchenOrderItem({
    required this.id,
    required this.name,
    this.variantName = '',
    required this.qty,
    this.toppings = const [],
  });

  factory KitchenOrderItem.fromJson(Map<String, dynamic> json) {
    return KitchenOrderItem(
      id: _toInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '-',
      variantName: json['variant_name']?.toString() ?? '',
      qty: _toInt(json['qty']) ?? 0,
      toppings: (json['toppings'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
    );
  }

  /// Nama lengkap termasuk varian, mis. "Es Teh Candi (Large)".
  String get displayName =>
      variantName.isEmpty ? name : '$name ($variantName)';
}

/// Satu pesanan terbayar yang sedang dikerjakan dapur.
class KitchenOrder {
  final int id;
  final int branchId;

  /// Nomor invoice. Bisa kosong untuk transaksi QRIS yang belum settle —
  /// tapi pesanan yang sampai ke layar ini selalu sudah lunas, jadi praktis
  /// selalu terisi.
  final String invoiceNo;

  /// Nama pelanggan (atas nama). Kosong bila kasir tidak mengisi.
  final String customerName;
  final String status;
  final String paymentMethod;
  final List<KitchenOrderItem> items;

  /// Waktu pembayaran dikonfirmasi. Null untuk transaksi lama (sebelum fitur
  /// ini ada) — dianggap tanpa timer.
  final DateTime? paidAt;
  final String cashierName;

  const KitchenOrder({
    required this.id,
    required this.branchId,
    this.invoiceNo = '',
    this.customerName = '',
    required this.status,
    this.paymentMethod = '',
    this.items = const [],
    this.paidAt,
    this.cashierName = '',
  });

  factory KitchenOrder.fromJson(Map<String, dynamic> json) {
    final rawPaidAt = json['paid_at']?.toString();
    return KitchenOrder(
      id: _toInt(json['id']) ?? 0,
      branchId: _toInt(json['branch_id']) ?? 0,
      invoiceNo: json['invoice_no']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      status: json['status']?.toString() ?? kitchenStatusQueued,
      paymentMethod: json['payment_method']?.toString() ?? '',
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => KitchenOrderItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      paidAt: (rawPaidAt == null || rawPaidAt.isEmpty)
          ? null
          : DateTime.tryParse(rawPaidAt)?.toLocal(),
      cashierName: json['cashier_name']?.toString() ?? '',
    );
  }

  KitchenOrder copyWith({String? status}) {
    return KitchenOrder(
      id: id,
      branchId: branchId,
      invoiceNo: invoiceNo,
      customerName: customerName,
      status: status ?? this.status,
      paymentMethod: paymentMethod,
      items: items,
      paidAt: paidAt,
      cashierName: cashierName,
    );
  }

  /// Sudah berapa lama pesanan ini menunggu sejak dibayar.
  Duration get waiting =>
      paidAt == null ? Duration.zero : DateTime.now().difference(paidAt!);

  /// Total item (bukan jumlah baris) — dipakai di header kartu.
  int get totalQty => items.fold(0, (sum, i) => sum + i.qty);

  /// Judul kartu: nomor invoice, atau nomor transaksi bila invoice kosong.
  String get displayNumber => invoiceNo.isNotEmpty ? invoiceNo : '#$id';
}

int? _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}
