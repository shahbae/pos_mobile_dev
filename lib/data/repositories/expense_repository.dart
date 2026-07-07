import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/api_services.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final ApiService api;
  ExpenseRepository(this.api);

  Future<List<ExpenseModel>> getExpenses({
    int page = 1,
    int limit = 50,
    String? from,
    String? to,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'page': page,
        'limit': limit,
      };
      if (from != null && from.isNotEmpty) queryParams['from'] = from;
      if (to != null && to.isNotEmpty) queryParams['to'] = to;

      final res = await api.dio.get('/expenses', queryParameters: queryParams);
      debugPrint('[ExpenseRepository] status=${res.statusCode} body=${res.data}');

      final List items = res.data['data']['items'] ?? [];
      return items.map((e) => ExpenseModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[ExpenseRepository] Error fetching expenses: $e');
      return [];
    }
  }

  /// Create pengeluaran — WAJIB foto bukti. multipart/form-data (breaking BE
  /// 2026-07-07). `branch_id`/`shift_id` diambil BE dari token & shift open.
  Future<Map<String, dynamic>> createExpense(
    Map<String, dynamic> data, {
    required String photoPath,
  }) async {
    try {
      final filename = photoPath.split(RegExp(r'[\\/]')).last;
      final form = FormData.fromMap({
        ...data,
        'photo': await MultipartFile.fromFile(photoPath, filename: filename),
      });
      final res = await api.dio.post(
        '/expenses',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      return res.data;
    } on DioException catch (e) {
      throw _mapCreateError(e);
    }
  }

  String _mapCreateError(DioException e) {
    final d = e.response?.data;
    final raw = (d is Map ? (d['message'] ?? d['error']) : null)
        ?.toString()
        .toLowerCase();
    if (raw != null) {
      if (raw.contains('photo is required')) return 'Foto bukti wajib diisi.';
      if (raw.contains('2mb') || raw.contains('≤ 2mb') || raw.contains('large')) {
        return 'Ukuran foto maksimal 2 MB.';
      }
      if (raw.contains('jpg') ||
          raw.contains('png') ||
          raw.contains('webp') ||
          raw.contains('allowed')) {
        return 'Format foto harus JPG, PNG, atau WEBP.';
      }
      if (raw.contains('parse form')) return 'Gagal mengunggah formulir.';
      if (raw.contains('invalid request')) {
        return 'Data tidak valid — periksa nominal, kategori, dan tanggal.';
      }
    }
    final msg = (d is Map ? (d['message'] ?? d['error']) : null)?.toString();
    return msg ?? 'Gagal menyimpan pengeluaran (${e.response?.statusCode ?? e.message})';
  }

  Future<ExpenseModel?> getExpenseDetail(int id) async {
    try {
      final res = await api.dio.get('/expenses/$id');
      final data = res.data['data'];
      if (data == null) return null;
      return ExpenseModel.fromJson(data);
    } catch (e) {
      debugPrint('[ExpenseRepository] Error fetching detail: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> updateExpense(int id, Map<String, dynamic> data) async {
    final res = await api.dio.put('/expenses/$id', data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> deleteExpense(int id) async {
    final res = await api.dio.delete('/expenses/$id');
    return res.data;
  }
}
