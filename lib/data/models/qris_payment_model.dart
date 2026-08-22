import 'package:pos_mobile/data/models/product_transaction_model.dart';

/// Model untuk alur QRIS dinamis. Dua mode cabang, satu bentuk response:
/// - `midtrans` — gateway yang mengonfirmasi (docs/api-qris-midtrans-fe.md)
/// - `manual`   — QR statis cabang dibuat dinamis di BE, kasir yang menekan
///                "Diterima" (docs/api-qris-manual-fe.md)

/// Nilai status yang mungkin dari BE.
class QrisStatusValue {
  static const pending = 'pending';
  static const paid = 'paid';
  static const expired = 'expired';
  static const cancelled = 'cancelled';
  static const denied = 'denied';
  static const refunded = 'refunded';
}

/// Nilai `provider` / mode QRIS cabang.
class QrisProvider {
  static const manual = 'manual';
  static const midtrans = 'midtrans';
}

/// Hasil charge QRIS ketika Midtrans aktif (Response A): kembalikan QR.
class QrisCharge {
  final String paymentRef;
  final String status;
  final num grossAmount;
  final String qrString;
  final String? qrUrl;
  final DateTime? expiresAt;

  /// `manual` | `midtrans` — menentukan siapa yang mengonfirmasi pembayaran.
  final String provider;

  /// true → kasir harus menekan "Pembayaran Diterima" (mode manual).
  final bool manualConfirm;

  const QrisCharge({
    required this.paymentRef,
    required this.status,
    required this.grossAmount,
    required this.qrString,
    this.qrUrl,
    this.expiresAt,
    this.provider = QrisProvider.midtrans,
    this.manualConfirm = false,
  });

  factory QrisCharge.fromJson(Map<String, dynamic> json) {
    return QrisCharge(
      paymentRef: json['payment_ref']?.toString() ?? '',
      status: json['status']?.toString() ?? QrisStatusValue.pending,
      grossAmount: _toNum(json['gross_amount']),
      qrString: json['qr_string']?.toString() ?? '',
      qrUrl: json['qr_url']?.toString(),
      expiresAt: _toDate(json['expires_at']),
      provider: json['provider']?.toString() ?? QrisProvider.midtrans,
      manualConfirm: _toBool(json['manual_confirm']),
    );
  }
}

/// Hasil polling status QRIS (`GET /qris-payments/{payment_ref}`), sekaligus
/// bentuk response konfirmasi manual (`POST .../confirm`).
class QrisStatus {
  final String status;
  final DateTime? expiresAt;

  /// Nomor invoice hanya terisi saat status `paid` (dari objek `receipt`).
  final String? invoiceNo;

  final String? provider;

  /// Ikut jadi `false` begitu pembayaran lunas / bukan mode manual.
  final bool manualConfirm;

  const QrisStatus({
    required this.status,
    this.expiresAt,
    this.invoiceNo,
    this.provider,
    this.manualConfirm = false,
  });

  bool get isPending => status == QrisStatusValue.pending;
  bool get isPaid => status == QrisStatusValue.paid;

  factory QrisStatus.fromJson(Map<String, dynamic> json) {
    final receipt = json['receipt'];
    String? invoice;
    if (receipt is Map) {
      invoice = (receipt['invoice_no'] ?? receipt['invoice_number'])?.toString();
    }
    return QrisStatus(
      status: json['status']?.toString() ?? QrisStatusValue.pending,
      expiresAt: _toDate(json['expires_at']),
      invoiceNo: invoice,
      provider: json['provider']?.toString(),
      manualConfirm: _toBool(json['manual_confirm']),
    );
  }
}

/// Sebab gagalnya konfirmasi manual — menentukan aksi FE
/// (docs/api-qris-manual-fe.md §2).
enum QrisConfirmFailure {
  /// 409 — pembayaran ini dikonfirmasi otomatis oleh gateway.
  gatewayAuto,

  /// 409 — QR sudah kedaluwarsa.
  expired,

  /// 409 — sudah tidak menunggu konfirmasi (device lain menyelesaikan).
  notPending,

  /// 404 — payment tidak ditemukan.
  notFound,
  other,
}

/// Error khusus tombol "Pembayaran Diterima" supaya layar QR bisa memilih aksi
/// yang tepat tanpa mencocokkan teks pesan sendiri.
class QrisConfirmException implements Exception {
  final QrisConfirmFailure kind;
  final String message;

  const QrisConfirmException(this.kind, this.message);

  @override
  String toString() => message;
}

/// Union hasil charge: pending (tampilkan QR) atau langsung selesai (receipt).
sealed class QrisChargeResult {
  const QrisChargeResult();
}

/// Response A — QRIS dinamis aktif, ada QR untuk di-scan.
class QrisChargePending extends QrisChargeResult {
  final QrisCharge charge;
  const QrisChargePending(this.charge);
}

/// Response B — Midtrans belum aktif, transaksi langsung lunas (receipt biasa).
class QrisChargeCompleted extends QrisChargeResult {
  final ProductTransactionResponse response;
  const QrisChargeCompleted(this.response);
}

/// Konfigurasi QRIS cabang (`GET/PUT/DELETE /branches/{id}/qris`).
class QrisBranchConfig {
  final int branchId;

  /// `manual` | `midtrans`.
  final String mode;

  /// `branch` = cabang punya setting sendiri, `default` = ikut setting server.
  final String modeSource;

  /// true bila payload QR statis sudah tersimpan.
  final bool configured;

  final String? merchantName;
  final String? nmid;
  final String? payload;
  final DateTime? updatedAt;

  const QrisBranchConfig({
    required this.branchId,
    required this.mode,
    required this.modeSource,
    required this.configured,
    this.merchantName,
    this.nmid,
    this.payload,
    this.updatedAt,
  });

  bool get isManual => mode == QrisProvider.manual;
  bool get isBranchOverride => modeSource == 'branch';

  factory QrisBranchConfig.fromJson(Map<String, dynamic> json) {
    return QrisBranchConfig(
      branchId: (json['branch_id'] as num?)?.toInt() ?? 0,
      mode: json['mode']?.toString() ?? QrisProvider.midtrans,
      modeSource: json['mode_source']?.toString() ?? 'default',
      configured: _toBool(json['configured']),
      merchantName: _emptyToNull(json['merchant_name']),
      nmid: _emptyToNull(json['nmid']),
      payload: _emptyToNull(json['payload']),
      updatedAt: _toDate(json['updated_at']),
    );
  }
}

String? _emptyToNull(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

bool _toBool(dynamic v) {
  if (v is bool) return v;
  final s = v?.toString().toLowerCase();
  return s == 'true' || s == '1';
}

num _toNum(dynamic v) {
  if (v is num) return v;
  return num.tryParse(v?.toString() ?? '') ?? 0;
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}
