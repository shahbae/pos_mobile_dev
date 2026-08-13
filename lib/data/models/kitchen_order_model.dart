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

/// Status kelima, **hanya dibuat sistem** saat kasir menutup shift: semua
/// pesanan yang masih di layar disapu ke sini supaya shift berikutnya mulai
/// bersih (docs/api-prep-time-dan-reset-kds-fe.md §2). PATCH status menolaknya
/// dengan 400 — jangan pernah dikirim dari sini. Di layar diperlakukan sama
/// seperti `served`: kartunya dihapus.
const kitchenStatusClosed = 'closed';

/// Status yang membuat kartu hilang dari layar.
bool isKitchenTerminalStatus(String status) =>
    status == kitchenStatusServed || status == kitchenStatusClosed;

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
    case kitchenStatusClosed:
      return 'Tutup Shift';
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

  /// Estimasi waktu pembuatan (menit, sudah dibulatkan ke kelipatan 5) —
  /// nilainya sama persis dengan yang tercetak di nota pelanggan. `0` =
  /// produknya belum diisi waktu pembuatan, bukan berarti instan.
  final int prepMinutes;

  /// Janji siap yang dibekukan saat pembayaran. Null = tidak ada estimasi →
  /// jangan tampilkan penanda telat sama sekali.
  final DateTime? estimatedReadyAt;

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
    this.prepMinutes = 0,
    this.estimatedReadyAt,
  });

  factory KitchenOrder.fromJson(Map<String, dynamic> json) {
    final rawPaidAt = json['paid_at']?.toString();
    final rawReadyAt = json['estimated_ready_at']?.toString();
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
      prepMinutes: _toInt(json['prep_minutes']) ?? 0,
      estimatedReadyAt: (rawReadyAt == null || rawReadyAt.isEmpty)
          ? null
          : DateTime.tryParse(rawReadyAt)?.toLocal(),
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
      prepMinutes: prepMinutes,
      estimatedReadyAt: estimatedReadyAt,
    );
  }

  /// Sudah berapa lama pesanan ini menunggu sejak dibayar.
  Duration get waiting =>
      paidAt == null ? Duration.zero : DateTime.now().difference(paidAt!);

  /// Ada janji siap yang bisa ditampilkan/dinilai.
  bool get hasEstimate => estimatedReadyAt != null;

  /// Sudah lewat janji siap. Tanpa estimasi selalu `false` — bukan berarti
  /// tepat waktu, tapi memang tidak ada yang bisa dinilai.
  bool get isLate =>
      estimatedReadyAt != null && DateTime.now().isAfter(estimatedReadyAt!);

  /// Selisih terhadap janji siap: positif = telat sekian, negatif = sisa waktu.
  Duration get lateness => estimatedReadyAt == null
      ? Duration.zero
      : DateTime.now().difference(estimatedReadyAt!);

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
