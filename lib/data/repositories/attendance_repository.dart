import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/attendance_model.dart';
import '../services/api_services.dart';

class AttendanceRepository {
  final ApiService api;
  AttendanceRepository(this.api);

  /// Status absensi hari ini (self). `null` jika belum check-in.
  Future<AttendanceModel?> getToday() async {
    final res = await api.dio.get('/attendance/me/today');
    debugPrint('[AttendanceRepo] today status=${res.statusCode} body=${res.data}');
    final data = res.data['data'];
    if (data == null || data is! Map) return null;
    return AttendanceModel.fromJson(Map<String, dynamic>.from(data));
  }

  /// Check-in: kirim selfie + GPS + cabang aktif + shift. multipart/form-data.
  Future<AttendanceModel> checkIn({
    required String photoPath,
    required int branchId,
    required String shift,
    required double latitude,
    required double longitude,
  }) async {
    final form = FormData.fromMap({
      'photo': await _photoPart(photoPath),
      'branch_id': branchId,
      'shift': shift,
      'latitude': latitude,
      'longitude': longitude,
    });
    return _submit('/attendance/check-in', form, 'Gagal melakukan absen masuk');
  }

  /// Check-out: branch_id diambil otomatis dari record check-in hari ini.
  Future<AttendanceModel> checkOut({
    required String photoPath,
    required double latitude,
    required double longitude,
  }) async {
    final form = FormData.fromMap({
      'photo': await _photoPart(photoPath),
      'latitude': latitude,
      'longitude': longitude,
    });
    return _submit('/attendance/check-out', form, 'Gagal melakukan absen pulang');
  }

  Future<MultipartFile> _photoPart(String path) {
    final filename = path.split(RegExp(r'[\\/]')).last;
    return MultipartFile.fromFile(path, filename: filename);
  }

  Future<AttendanceModel> _submit(
    String path,
    FormData form,
    String fallback,
  ) async {
    try {
      final res = await api.dio.post(
        path,
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      final data = res.data['data'];
      if (data == null || data is! Map) {
        throw res.data['message']?.toString() ?? fallback;
      }
      return AttendanceModel.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw _mapError(e, fallback);
    }
  }

  String _mapError(DioException e, String fallback) {
    final data = e.response?.data;
    final raw = (data is Map ? (data['message'] ?? data['error']) : null)
        ?.toString()
        .toLowerCase();
    if (raw != null) {
      if (raw.contains('already checked out')) return 'Anda sudah absen pulang hari ini.';
      if (raw.contains('not checked in')) return 'Anda belum absen masuk hari ini.';
      if (raw.contains('branch is not active')) return 'Cabang sedang tidak aktif.';
      if (raw.contains('branch')) return 'Cabang tidak valid.';
      if (raw.contains('size') || raw.contains('5mb') || raw.contains('large')) {
        return 'Ukuran foto maksimal 5 MB.';
      }
      if (raw.contains('jpg') || raw.contains('png') || raw.contains('format')) {
        return 'Format foto harus JPG atau PNG.';
      }
    }
    if (e.response?.statusCode == 409) return 'Anda sudah absen hari ini.';
    final msg = (data is Map ? (data['message'] ?? data['error']) : null)?.toString();
    return msg ?? '$fallback (${e.response?.statusCode ?? e.message})';
  }
}
