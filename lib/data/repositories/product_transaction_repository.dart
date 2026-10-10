import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/product_transaction_model.dart';
import 'package:pos_mobile/data/models/qris_payment_model.dart';
import 'package:pos_mobile/data/services/api_services.dart';
import 'package:flutter/foundation.dart';

import 'package:pos_mobile/data/services/api_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_scope.dart';

final productTransactionRepositoryProvider = Provider<ProductTransactionRepository>((ref) {
  // Ikut lahir ulang saat pindah cabang — lihat [branchScopeProvider].
  ref.watch(branchScopeProvider);
  final api = ref.watch(apiProvider);
  return ProductTransactionRepository(api);
});

class ProductTransactionRepository {
  final ApiService api;
  ProductTransactionRepository(this.api);

  Future<ProductTransactionResponse> createTransaction(ProductTransactionRequest request) async {
    try {
      debugPrint('[TransactionRepo] POST /product-transactions body: ${request.toJson()}');
      // Batasnya lebih pendek dari permintaan lain: pembeli sedang menunggu di
      // depan kasir, dan bila server tak menjawab penjualannya masih bisa
      // disimpan di HP. Permintaan yang terlanjur sampai tetap aman — kiriman
      // ulangnya memakai idempotency key yang sama.
      final res = await api.dio
          .post(
            '/product-transactions',
            data: request.toJson(),
            options: Options(sendTimeout: _saleTimeout, receiveTimeout: _saleTimeout),
          )
          .timeout(_saleTimeout + const Duration(seconds: 2));

      debugPrint('[TransactionRepo] Response: ${res.data}');
      // Key yang sama pernah dipakai percobaan QRIS dan QR-nya masih menunggu:
      // server membalas QR itu, bukan struk. Tanpa cek ini balasannya terbaca
      // sebagai transaksi berhasil dengan nomor invoice kosong.
      if (_isPendingQr(_dataOf(res.data))) {
        throw const TransactionSubmitException(
          'Pesanan ini sudah punya QR QRIS yang masih menunggu pembayaran. '
          'Pilih QRIS untuk menampilkannya lagi.',
          rejected: false,
        );
      }
      return ProductTransactionResponse.fromJson(res.data);
    } on DioException catch (e) {
      debugPrint('[TransactionRepo] DioError ${e.response?.statusCode}: ${e.response?.data}');
      throw _submitError(e);
    } on TimeoutException {
      throw const TransactionSubmitException(
        'Tidak ada jawaban dari server',
        rejected: false,
        unreachable: true,
      );
    }
  }

  static const _saleTimeout = Duration(seconds: 10);

  /// Charge QRIS: sama-sama `POST /product-transactions` (payment_method "qris"),
  /// tapi response bisa 2 bentuk — QR (pending) atau receipt biasa (langsung lunas).
  Future<QrisChargeResult> createQrisTransaction(ProductTransactionRequest request) async {
    try {
      final payload = request.toJson(forQris: true);
      debugPrint('[TransactionRepo] POST /product-transactions (QRIS) body: $payload');
      final res = await api.dio.post('/product-transactions', data: payload);
      debugPrint('[TransactionRepo] QRIS response: ${res.data}');
      final body = res.data;
      final data = _dataOf(body);

      // Response A: ada qr_string / payment_ref tanpa invoice → tampilkan QR.
      if (_isPendingQr(data)) {
        return QrisChargePending(QrisCharge.fromJson(Map<String, dynamic>.from(data)));
      }
      // Response B: receipt biasa (langsung lunas).
      return QrisChargeCompleted(
          ProductTransactionResponse.fromJson(Map<String, dynamic>.from(body)));
    } on DioException catch (e) {
      throw _submitError(e);
    }
  }

  dynamic _dataOf(dynamic body) =>
      (body is Map && body['data'] is Map) ? body['data'] as Map : body;

  /// Bentuk response QR yang menunggu pembayaran: ada qr_string / payment_ref
  /// tanpa nomor invoice.
  bool _isPendingQr(dynamic data) =>
      data is Map &&
      (data['qr_string'] != null || data['payment_ref'] != null) &&
      data['invoice_no'] == null &&
      data['invoice_number'] == null;

  /// Galat `POST /product-transactions`, dengan penanda apakah server memang
  /// menolaknya — lihat [TransactionSubmitException.rejected].
  TransactionSubmitException _submitError(DioException e) {
    final data = e.response?.data;
    final raw = (data is Map) ? (data['message'] ?? data['error']) : null;
    final status = e.response?.statusCode;
    return TransactionSubmitException(
      _mapError(raw?.toString(), status, e.message),
      rejected: status != null && status >= 400 && status < 500,
      unreachable: e.response == null,
      statusCode: status,
    );
  }

  /// Kirim satu penjualan yang dibuat saat offline. [payload] adalah isi yang
  /// dibekukan saat penjualan terjadi; mengirimnya ulang dengan
  /// `idempotency_key` yang sama dibalas transaksi yang sudah tercatat.
  ///
  /// Mengembalikan nomor invoice resminya.
  Future<String> sendOffline(Map<String, dynamic> payload) async {
    try {
      final res = await api.dio.post('/product-transactions/offline', data: payload);
      final data = _dataOf(res.data);
      final invoice = data is Map ? data['invoice_no']?.toString() ?? '' : '';
      debugPrint('[TransactionRepo] offline ${payload['client_ref']} -> $invoice');
      return invoice;
    } on DioException catch (e) {
      throw _submitError(e);
    }
  }

  /// Apakah server terjangkau saat ini. Dipakai untuk memutuskan kapan mode
  /// offline boleh berakhir; jawabannya cepat karena tidak menyentuh data.
  Future<bool> ping() async {
    try {
      await api.dio.get(
        '/health',
        options: Options(sendTimeout: _pingTimeout, receiveTimeout: _pingTimeout),
      ).timeout(_pingTimeout + const Duration(seconds: 2));
      return true;
    } catch (_) {
      return false;
    }
  }

  static const _pingTimeout = Duration(seconds: 5);

  /// Cek status pembayaran QRIS (polling).
  Future<QrisStatus> getQrisStatus(String paymentRef) async {
    try {
      final res = await api.dio.get('/qris-payments/$paymentRef');
      final data = res.data['data'];
      if (data is! Map) throw 'Data status tidak ditemukan';
      return QrisStatus.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      final data = e.response?.data;
      final raw = (data is Map) ? (data['message'] ?? data['error']) : null;
      throw _mapError(raw?.toString(), e.response?.statusCode, e.message);
    }
  }

  /// Konfirmasi manual oleh kasir (mode `manual`, saat `manual_confirm == true`).
  /// Sukses → status `paid` beserta receipt. Gagal → [QrisConfirmException]
  /// dengan sebab yang sudah dipetakan (docs/api-qris-manual-fe.md §2).
  Future<QrisStatus> confirmQris(String paymentRef) async {
    try {
      final res = await api.dio.post('/qris-payments/$paymentRef/confirm');
      final data = res.data['data'];
      if (data is! Map) throw 'Data konfirmasi tidak ditemukan';
      return QrisStatus.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      final data = e.response?.data;
      final raw = (data is Map) ? (data['message'] ?? data['error']) : null;
      throw _mapConfirmError(raw?.toString(), e.response?.statusCode);
    }
  }

  QrisConfirmException _mapConfirmError(String? raw, int? status) {
    final msg = raw?.trim() ?? '';
    final key = msg.toLowerCase();
    if (status == 404) {
      return QrisConfirmException(
          QrisConfirmFailure.notFound, 'Pembayaran tidak ditemukan');
    }
    if (key.contains('otomatis')) {
      return QrisConfirmException(QrisConfirmFailure.gatewayAuto,
          msg.isEmpty ? 'Pembayaran dikonfirmasi otomatis oleh gateway' : msg);
    }
    if (key.contains('kedaluwarsa') || key.contains('expired')) {
      return QrisConfirmException(QrisConfirmFailure.expired,
          msg.isEmpty ? 'QR sudah kedaluwarsa' : msg);
    }
    if (key.contains('menunggu konfirmasi')) {
      return QrisConfirmException(QrisConfirmFailure.notPending,
          msg.isEmpty ? 'Pembayaran sudah tidak menunggu konfirmasi' : msg);
    }
    return QrisConfirmException(QrisConfirmFailure.other,
        msg.isEmpty ? 'Gagal mengonfirmasi pembayaran ($status)' : msg);
  }

  /// Batalkan QRIS yang masih pending. Return status akhir dari BE
  /// (bisa `cancelled`, atau `paid` bila pelanggan keburu bayar — aman terhadap race).
  Future<String> cancelQris(String paymentRef) async {
    try {
      final res = await api.dio.post('/qris-payments/$paymentRef/cancel');
      final data = res.data['data'];
      if (data is Map && data['status'] != null) return data['status'].toString();
      return QrisStatusValue.cancelled;
    } on DioException catch (e) {
      final data = e.response?.data;
      final raw = (data is Map) ? (data['message'] ?? data['error']) : null;
      throw _mapError(raw?.toString(), e.response?.statusCode, e.message);
    }
  }

  /// Petakan pesan error BE → pesan Indonesia yang ramah kasir.
  String _mapError(String? raw, int? status, String? fallback) {
    final key = raw?.toLowerCase().trim() ?? '';
    const map = <String, String>{
      'invalid input': 'Input tidak valid',
      'free toppings not allowed': 'Produk ini tidak punya topping gratis',
      'free topping slots exceeded': 'Topping gratis melebihi slot yang tersedia',
      'insufficient paid amount': 'Jumlah bayar kurang dari total',
      'free topping not allowed': 'Produk ini tidak punya topping gratis',
      'free qty exceeded': 'Jumlah item gratis melebihi yang diizinkan promo',
      'free qty exceeds allowed amount':
          'Jumlah item gratis melebihi yang diizinkan promo',
      'promo not applicable today': 'Promo tidak berlaku hari ini',
      'product not found': 'Produk tidak ditemukan',
      'topping not found': 'Topping tidak ditemukan',
      'topping inactive': 'Topping sedang tidak aktif',
      'free item not in order': 'Item gratis tidak ada di pesanan',
      'free item product must be in the order': 'Item gratis harus ada di pesanan',
      'free item category is not eligible for free items':
          'Kategori produk ini tidak bisa dijadikan item gratis',
      'free item price exceeds the cheapest item in order':
          'Item gratis tidak boleh lebih mahal dari item termurah di keranjang',
      'variant not found': 'Variasi produk tidak ditemukan',
      'variant is not active': 'Variasi produk sedang tidak aktif',
      'variant does not belong to product': 'Variasi tidak sesuai dengan produk',
      'no active shift for this branch':
          'Belum ada shift aktif. Buka shift kasir terlebih dahulu.',
      'product not ready: insufficient material stock':
          'Stok bahan produk/varian ini habis. Refresh daftar produk lalu coba lagi.',
      'plastic not found': 'Plastik/kemasan tidak ditemukan',
      'plastic is not active': 'Plastik/kemasan sedang tidak aktif',
      'sedotan not found': 'Sedotan tidak ditemukan',
      'sedotan is not active': 'Sedotan sedang tidak aktif',
    };
    if (map.containsKey(key)) return map[key]!;
    if (raw != null && raw.isNotEmpty) return raw;
    return 'Gagal membuat transaksi (${status ?? fallback})';
  }
}
