import 'package:dio/dio.dart';

import '../models/schedule_model.dart';
import '../services/api_services.dart';

/// Jadwal saya (Tahap 1 SDM). Menyusun jadwal ada di web admin, bukan di sini.
class ScheduleRepository {
  final ApiService api;
  ScheduleRepository(this.api);

  /// `GET /schedules/me` — hanya bulan yang sudah disetujui. Tanpa rentang:
  /// awal bulan ini sampai akhir bulan depan.
  Future<List<MyScheduleEntry>> getMine({String? from, String? to}) async {
    try {
      final res = await api.dio.get('/schedules/me', queryParameters: {
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      });
      final data = res.data['data'];
      if (data is! List) return const [];
      return [
        for (final e in data)
          if (e is Map) MyScheduleEntry.fromJson(Map<String, dynamic>.from(e)),
      ];
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map ? (data['message'] ?? data['error'])?.toString() : null;
      throw msg ?? 'Gagal memuat jadwal (${e.response?.statusCode ?? e.message})';
    }
  }
}
