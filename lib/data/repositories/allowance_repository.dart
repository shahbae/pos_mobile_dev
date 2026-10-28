import 'package:dio/dio.dart';

import '../models/allowance_model.dart';
import '../models/page_result.dart';
import '../services/api_services.dart';

/// Jatah karyawan (Tahap 3, F7): penerima untuk kasir, saldo dan riwayat
/// milik sendiri. Pesanan jatahnya sendiri lewat `POST /product-transactions`.
class AllowanceRepository {
  final ApiService api;
  AllowanceRepository(this.api);

  /// Yang sudah absen masuk hari ini di lokasi mana pun, outlet ini dulu.
  Future<List<AllowanceRecipient>> recipients() async {
    try {
      final res = await api.dio.get('/allowance/recipients');
      final data = res.data['data'];
      if (data is! List) return const [];
      return [
        for (final row in data)
          if (row is Map) AllowanceRecipient.fromJson(Map<String, dynamic>.from(row)),
      ];
    } on DioException catch (e) {
      throw _message(e, 'Gagal memuat daftar penerima jatah');
    }
  }

  Future<MyAllowance> mine() async {
    try {
      final res = await api.dio.get('/me/allowance');
      final data = res.data['data'];
      if (data is! Map) throw 'Gagal memuat jatah';
      return MyAllowance.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw _message(e, 'Gagal memuat jatah');
    }
  }

  Future<PageResult<AllowanceOrder>> myOrders(int page, int limit) async {
    try {
      final res = await api.dio.get('/me/allowance/orders', queryParameters: {'page': page, 'limit': limit});
      return PageResult.parse(res.data['data'], AllowanceOrder.fromJson, page: page, limit: limit);
    } on DioException catch (e) {
      throw _message(e, 'Gagal memuat riwayat jatah');
    }
  }

  /// Pesan BE sudah berbahasa Indonesia; yang diganti hanya galat jaringan.
  String _message(DioException e, String fallback) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return 'Tidak bisa menghubungi server. Periksa koneksi lalu coba lagi.';
      default:
        break;
    }
    final data = e.response?.data;
    final msg = data is Map ? data['message']?.toString() : null;
    return (msg == null || msg.isEmpty) ? fallback : msg;
  }
}
