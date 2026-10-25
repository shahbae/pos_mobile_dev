import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/attendance_model.dart';
import '../models/leave_out_model.dart';
import '../models/my_day_model.dart';
import '../services/api_services.dart';

/// Pesan untuk `403 no branch assigned` — user belum ditugaskan ke cabang.
/// Sengaja bukan "akses ditolak": ini soal assignment, bukan role.
const kNoBranchAssignedMsg =
    'Akun Anda belum ditugaskan ke cabang. Hubungi owner untuk assign cabang.';

/// Kasir/karyawan tanpa cabang di token (Tahap 1 SDM): cabangnya mengikuti
/// jadwal hari ini, dan hari ini ia tidak terjadwal di outlet mana pun.
const kNoScheduleTodayMsg =
    'Belum ada jadwal hari ini. Minta leader mengisi jadwalmu, lalu tekan Muat ulang.';

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

  /// Hari saya (Tahap 1 SDM): shift hari ini beserta statusnya, absen hari
  /// ini, dan apakah masih ada shift lagi. Server lama tanpa endpoint ini (404)
  /// → disusun dari `/attendance/me/today`.
  Future<MyDay> getMyDay() async {
    try {
      final res = await api.dio.get('/attendance/me/day');
      final data = res.data['data'];
      if (data is! Map) throw 'Gagal memuat absensi hari ini';
      return MyDay.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return MyDay.fromToday(await getToday());
      rethrow;
    }
  }

  /// Check-in: kirim selfie + GPS (+ shift). multipart/form-data.
  ///
  /// [shift] hanya untuk absen tanpa jadwal. Kalau ada jadwal yang jendelanya
  /// terbuka, server menempelkan absen ke jadwal itu dan mengabaikan shift.
  ///
  /// [branchId] hanya dikirim untuk owner & supervisor — untuk role lain BE
  /// mengabaikannya dan selalu memakai cabang dari token
  /// (docs/api-finance-absensi-fe.md §2), jadi kirim `null` saja.
  Future<AttendanceModel> checkIn({
    required String photoPath,
    int? branchId,
    String? shift,
    required double latitude,
    required double longitude,
  }) async {
    final form = FormData.fromMap({
      'photo': await _photoPart(photoPath),
      if (branchId != null) 'branch_id': branchId,
      if (shift != null) 'shift': shift,
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

  /// Yang sedang bertugas di cabang token (owner/SPV: [branchId]).
  Future<List<OnDutyModel>> onDuty({int? branchId}) async {
    try {
      final res = await api.dio.get(
        '/attendance/on-duty',
        queryParameters: {if (branchId != null) 'branch_id': branchId},
      );
      final data = res.data['data'];
      if (data is! List) return const [];
      return [
        for (final e in data)
          if (e is Map) OnDutyModel.fromJson(Map<String, dynamic>.from(e)),
      ];
    } on DioException catch (e) {
      throw _mapError(e, 'Gagal memuat yang sedang bertugas');
    }
  }

  /// Tandai lembur (leader outletnya, SPV, owner). Satu kali per absen.
  Future<AttendanceModel> markOvertime(int attendanceId) =>
      _attendanceCall(() => api.dio.post('/attendance/$attendanceId/overtime'),
          'Gagal menandai lembur');

  Future<AttendanceModel> unmarkOvertime(int attendanceId) =>
      _attendanceCall(() => api.dio.delete('/attendance/$attendanceId/overtime'),
          'Gagal mencabut lembur');

  /// Izin keluar sebentar dari outlet. [handoverUserId] = rekan yang sedang
  /// bertugas di outlet yang sama, boleh kosong.
  Future<LeaveOutModel> startLeaveOut({required String reason, int? handoverUserId}) =>
      _leaveOutCall(
        () => api.dio.post('/leave-outs', data: {
          'reason': reason,
          if (handoverUserId != null) 'handover_user_id': handoverUserId,
        }),
        'Gagal mencatat izin keluar',
      );

  Future<LeaveOutModel> endLeaveOut(int id) =>
      _leaveOutCall(() => api.dio.post('/leave-outs/$id/back'), 'Gagal mencatat kembali');

  /// Riwayat izin keluar (owner, SPV, leader cabangnya). Bawaan server 7 hari.
  Future<List<LeaveOutModel>> listLeaveOuts({String? from, String? to, int? branchId}) async {
    try {
      final res = await api.dio.get('/leave-outs', queryParameters: {
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (branchId != null) 'branch_id': branchId,
      });
      final data = res.data['data'];
      if (data is! List) return const [];
      return [
        for (final e in data)
          if (e is Map) LeaveOutModel.fromJson(Map<String, dynamic>.from(e)),
      ];
    } on DioException catch (e) {
      throw _mapError(e, 'Gagal memuat izin keluar');
    }
  }

  Future<AttendanceModel> _attendanceCall(
      Future<Response<dynamic>> Function() send, String fallback) async {
    try {
      final res = await send();
      final data = res.data['data'];
      if (data is! Map) throw res.data['message']?.toString() ?? fallback;
      return AttendanceModel.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw _mapError(e, fallback);
    }
  }

  Future<LeaveOutModel> _leaveOutCall(
      Future<Response<dynamic>> Function() send, String fallback) async {
    try {
      final res = await send();
      final data = res.data['data'];
      if (data is! Map) throw res.data['message']?.toString() ?? fallback;
      return LeaveOutModel.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw _mapError(e, fallback);
    }
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
      // Revisi 17 Okt 2026: absen pulang hanya sesudah shift ditutup.
      if (raw.contains('tutup shift')) {
        return 'Tutup shift dulu sebelum absen pulang.';
      }
      if (raw.contains('not checked in')) return 'Anda belum absen masuk hari ini.';
      if (raw.contains('branch is not active')) return 'Cabang sedang tidak aktif.';
      // Kasir/karyawan yang tidak terjadwal hari ini (Tahap 1 SDM).
      if (raw.contains('belum ada jadwal')) return kNoScheduleTodayMsg;
      // Bukan masalah role: user belum di-assign cabang oleh owner.
      if (raw.contains('no branch assigned')) return kNoBranchAssignedMsg;
      if (raw.contains('shift is required')) return 'Pilih shift dulu.';
      if (raw.startsWith('forbidden')) return 'Akun Anda tidak berwenang melakukan ini.';
      if (raw.contains('branch')) return 'Cabang tidak valid.';
      if (raw.contains('size') || raw.contains('5mb') || raw.contains('large')) {
        return 'Ukuran foto maksimal 5 MB.';
      }
      if (raw.contains('jpg') || raw.contains('png') || raw.contains('format')) {
        return 'Format foto harus JPG atau PNG.';
      }
    }
    final msg = (data is Map ? (data['message'] ?? data['error']) : null)?.toString();
    // Pesan berbahasa Indonesia dari server (jadwal, lembur, izin keluar)
    // sudah ditulis untuk orang di outlet: diteruskan apa adanya.
    if (msg != null && _looksIndonesian(msg)) return _capitalize(msg);
    if (e.response?.statusCode == 409) return 'Anda sudah absen hari ini.';
    return msg ?? '$fallback (${e.response?.statusCode ?? e.message})';
  }

  static bool _looksIndonesian(String msg) {
    final m = msg.toLowerCase();
    return const ['jadwal', 'absen', 'lembur', 'izin', 'kamu', 'rekan', 'shift ', 'alasan']
        .any(m.contains);
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
