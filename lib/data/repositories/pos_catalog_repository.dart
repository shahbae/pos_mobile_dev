import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:pos_mobile/data/models/pos_catalog_model.dart';
import 'package:pos_mobile/data/services/api_services.dart';

class PosCatalogRepository {
  final ApiService api;
  PosCatalogRepository(this.api);

  /// Ambil katalog cabang aktif. Bila [version] masih berlaku, server hanya
  /// menjawab `unchanged` tanpa daftar apa pun.
  Future<PosCatalogFetch> fetch({String? version}) async {
    try {
      final res = await api.dio.get(
        '/pos/catalog',
        queryParameters: {if (version != null && version.isNotEmpty) 'version': version},
      );
      final data = res.data is Map ? res.data['data'] : null;
      if (data is! Map) throw 'Jawaban katalog dari server tidak terbaca';
      final fetch = PosCatalogFetch.fromJson(
        Map<String, dynamic>.from(data),
        fetchedAt: DateTime.now(),
      );
      debugPrint('[PosCatalog] version=${fetch.version} unchanged=${fetch.unchanged}');
      return fetch;
    } on DioException catch (e) {
      final data = e.response?.data;
      final raw = (data is Map) ? (data['message'] ?? data['error']) : null;
      if (e.response == null) throw 'Tidak bisa menghubungi server. Periksa koneksi.';
      throw raw?.toString() ?? 'Gagal memuat katalog (${e.response?.statusCode})';
    }
  }
}
