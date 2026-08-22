import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../services/api_services.dart';
import '../models/purchase_model.dart';

class PurchaseRepository {
  final ApiService api;
  PurchaseRepository(this.api);

  static final _dayFmt = DateFormat('yyyy-MM-dd');

  static String _day(DateTime d) => _dayFmt.format(DateTime(d.year, d.month, d.day));

  /// [from]/[to] adalah tanggal kalender di timezone app (Asia/Jakarta) dan
  /// **inklusif** di kedua ujung — BE 2026-08-03 §1 memperbaiki parsing yang
  /// dulu memakai UTC sehingga jendela filternya bergeser 7 jam.
  Future<List<PurchaseModel>> getPurchases({
    int page = 1,
    int limit = 10,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async {
    final res = await api.dio.get(
      '/purchases',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.isNotEmpty) 'search': search,
        if (from != null) 'from': _day(from),
        if (to != null) 'to': _day(to),
      },
    );

    debugPrint('[PurchaseRepo] status=${res.statusCode} body=${res.data}');

    final data = res.data['data'];
    if (data == null) return [];

    List listData = [];
    if (data is Map && data['items'] is List) {
      listData = data['items'];
    } else if (data is List) {
      listData = data;
    }

    return listData.map((e) => PurchaseModel.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> createPurchase(Map<String, dynamic> data) async {
    try {
      final res = await api.dio.post('/purchases', data: data);
      return res.data;
    } on DioException catch (e) {
      debugPrint('[PurchaseRepo] create error ${e.response?.statusCode}: ${e.response?.data}');
      final body = e.response?.data;
      final msg = (body is Map) ? (body['message'] ?? body['error']) : null;
      throw msg?.toString() ?? 'Gagal menyimpan pembelian (${e.response?.statusCode ?? e.message})';
    }
  }

  Future<PurchaseModel> getPurchaseDetail(int id) async {
    final res = await api.dio.get('/purchases/$id');
    return PurchaseModel.fromJson(res.data['data']);
  }
}
