import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/product_transaction_model.dart';
import 'package:pos_mobile/data/models/qris_payment_model.dart';
import 'package:pos_mobile/data/services/api_services.dart';
import 'package:flutter/foundation.dart';

import 'package:pos_mobile/data/services/api_provider.dart';

final productTransactionRepositoryProvider = Provider<ProductTransactionRepository>((ref) {
  final api = ref.watch(apiProvider);
  return ProductTransactionRepository(api);
});

class ProductTransactionRepository {
  final ApiService api;
  ProductTransactionRepository(this.api);

  Future<ProductTransactionResponse> createTransaction(ProductTransactionRequest request) async {
    try {
      debugPrint('[TransactionRepo] POST /product-transactions body: ${request.toJson()}');
      final res = await api.dio.post(
        '/product-transactions',
        data: request.toJson(),
      );

      debugPrint('[TransactionRepo] Response: ${res.data}');
      return ProductTransactionResponse.fromJson(res.data);
    } on DioException catch (e) {
      debugPrint('[TransactionRepo] DioError ${e.response?.statusCode}: ${e.response?.data}');
      final data = e.response?.data;
      final raw = (data is Map) ? (data['message'] ?? data['error']) : null;
      throw _mapError(raw?.toString(), e.response?.statusCode, e.message);
    }
  }

  /// Charge QRIS: sama-sama `POST /product-transactions` (payment_method "qris"),
  /// tapi response bisa 2 bentuk — QR (pending) atau receipt biasa (langsung lunas).
  Future<QrisChargeResult> createQrisTransaction(ProductTransactionRequest request) async {
    try {
      final payload = request.toJson(forQris: true);
      debugPrint('[TransactionRepo] POST /product-transactions (QRIS) body: $payload');
      final res = await api.dio.post('/product-transactions', data: payload);
      debugPrint('[TransactionRepo] QRIS response: ${res.data}');
      final body = res.data;
      final data = (body is Map && body['data'] is Map) ? body['data'] as Map : body;

      // Response A: ada qr_string / payment_ref tanpa invoice → tampilkan QR.
      final hasQr = data is Map &&
          (data['qr_string'] != null || data['payment_ref'] != null) &&
          data['invoice_no'] == null &&
          data['invoice_number'] == null;
      if (hasQr) {
        return QrisChargePending(QrisCharge.fromJson(Map<String, dynamic>.from(data)));
      }
      // Response B: receipt biasa (langsung lunas).
      return QrisChargeCompleted(
          ProductTransactionResponse.fromJson(Map<String, dynamic>.from(body)));
    } on DioException catch (e) {
      final data = e.response?.data;
      final raw = (data is Map) ? (data['message'] ?? data['error']) : null;
      throw _mapError(raw?.toString(), e.response?.statusCode, e.message);
    }
  }

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
    };
    if (map.containsKey(key)) return map[key]!;
    if (raw != null && raw.isNotEmpty) return raw;
    return 'Gagal membuat transaksi (${status ?? fallback})';
  }
}
