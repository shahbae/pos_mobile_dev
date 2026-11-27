import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/sop_model.dart';
import '../services/api_services.dart';

/// SOP (revisi owner 26 Nov 2026). Server lama (404) → kosong.
class SopRepository {
  final ApiService api;
  SopRepository(this.api);

  Future<List<Sop>> list() async {
    try {
      final res = await api.dio.get('/sops');
      final data = res.data['data'];
      return [
        if (data is List)
          for (final e in data)
            if (e is Map) Sop.fromJson(Map<String, dynamic>.from(e)),
      ];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const [];
      final msg = e.response?.data is Map ? (e.response!.data as Map)['message']?.toString() : null;
      throw msg ?? (e.response == null ? 'Gagal memuat SOP: periksa koneksi internet' : 'Gagal memuat SOP');
    }
  }

  /// Unduh PDF SOP ke folder sementara aplikasi; mengembalikan path berkasnya.
  Future<String> downloadPdf(Sop sop) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/sop');
    if (!await dir.exists()) await dir.create(recursive: true);
    final path = '${dir.path}/sop-${sop.id}.pdf';
    try {
      await api.dio.download(sop.fileUrl, path, options: Options(receiveTimeout: const Duration(seconds: 60)));
      return path;
    } on DioException catch (_) {
      final f = File(path);
      if (await f.exists()) await f.delete();
      throw 'Gagal mengunduh PDF SOP';
    }
  }
}
