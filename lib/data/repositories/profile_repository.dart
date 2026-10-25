import 'package:dio/dio.dart';

import '../models/profile_model.dart';
import '../services/api_services.dart';

/// Profil sendiri (Tahap 1 SDM): data diri, foto, ganti password.
class ProfileRepository {
  final ApiService api;
  ProfileRepository(this.api);

  Future<ProfileModel> getMine() =>
      _profileCall(() => api.dio.get('/me/profile'), 'Gagal memuat profil');

  /// Pembaruan sebagian: hanya `phone`, `address`, `emergency_contact_name`,
  /// `emergency_contact_phone`. `""` mengosongkan.
  Future<ProfileModel> updateMine(Map<String, String> fields) =>
      _profileCall(() => api.dio.put('/me/profile', data: fields), 'Gagal menyimpan profil');

  Future<ProfileModel> updatePhoto(String path) async {
    final filename = path.split(RegExp(r'[\\/]')).last;
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(path, filename: filename),
    });
    return _profileCall(
      () => api.dio.put('/me/photo',
          data: form, options: Options(contentType: 'multipart/form-data')),
      'Gagal mengganti foto',
    );
  }

  /// Sukses = semua sesi akun ini keluar, termasuk HP ini.
  Future<void> changePassword({required String oldPassword, required String newPassword}) async {
    try {
      await api.dio.put('/me/password', data: {
        'old_password': oldPassword,
        'new_password': newPassword,
      });
    } on DioException catch (e) {
      throw _message(e, 'Gagal mengganti password');
    }
  }

  Future<ProfileModel> _profileCall(
      Future<Response<dynamic>> Function() send, String fallback) async {
    try {
      final res = await send();
      final data = res.data['data'];
      if (data is! Map) throw fallback;
      return ProfileModel.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw _message(e, fallback);
    }
  }

  String _message(DioException e, String fallback) {
    final data = e.response?.data;
    final raw = (data is Map ? (data['message'] ?? data['error']) : null)?.toString();
    if (raw == null) return '$fallback (${e.response?.statusCode ?? e.message})';
    final m = raw.toLowerCase();
    if (m.contains('phone')) return 'Nomor HP tidak valid.';
    if (m.contains('5mb')) return 'Ukuran foto maksimal 5 MB.';
    if (m.contains('jpg') || m.contains('png')) return 'Format foto harus JPG, PNG, atau WEBP.';
    return raw.isEmpty ? fallback : '${raw[0].toUpperCase()}${raw.substring(1)}';
  }
}
