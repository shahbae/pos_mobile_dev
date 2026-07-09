import 'package:pos_mobile/data/models/product_transaction_model.dart';

/// Model untuk alur QRIS dinamis (Midtrans). Lihat docs/api-qris-midtrans-fe.md.

/// Nilai status yang mungkin dari BE.
class QrisStatusValue {
  static const pending = 'pending';
  static const paid = 'paid';
  static const expired = 'expired';
  static const cancelled = 'cancelled';
  static const denied = 'denied';
  static const refunded = 'refunded';
}

/// Hasil charge QRIS ketika Midtrans aktif (Response A): kembalikan QR.
class QrisCharge {
  final String paymentRef;
  final String status;
  final num grossAmount;
  final String qrString;
  final String? qrUrl;
  final DateTime? expiresAt;

  const QrisCharge({
    required this.paymentRef,
    required this.status,
    required this.grossAmount,
    required this.qrString,
    this.qrUrl,
    this.expiresAt,
  });

  factory QrisCharge.fromJson(Map<String, dynamic> json) {
    return QrisCharge(
      paymentRef: json['payment_ref']?.toString() ?? '',
      status: json['status']?.toString() ?? QrisStatusValue.pending,
      grossAmount: _toNum(json['gross_amount']),
      qrString: json['qr_string']?.toString() ?? '',
      qrUrl: json['qr_url']?.toString(),
      expiresAt: _toDate(json['expires_at']),
    );
  }
}

/// Hasil polling status QRIS (`GET /qris-payments/{payment_ref}`).
class QrisStatus {
  final String status;
  final DateTime? expiresAt;

  /// Nomor invoice hanya terisi saat status `paid` (dari objek `receipt`).
  final String? invoiceNo;

  const QrisStatus({required this.status, this.expiresAt, this.invoiceNo});

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
    );
  }
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

num _toNum(dynamic v) {
  if (v is num) return v;
  return num.tryParse(v?.toString() ?? '') ?? 0;
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}
