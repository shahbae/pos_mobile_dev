import 'package:flutter/foundation.dart';
import '../services/api_services.dart';
import '../models/material_model.dart';

class MaterialRepository {
  final ApiService api;
  MaterialRepository(this.api);

  /// Bahan yang disimpan outlet. Hanya bahan setengah jadi (revisi 18 Sep
  /// 2026): bahan mentah dibeli dan disimpan gudang, tidak pernah ada di rak
  /// outlet. BE juga sudah menyaring bahan mentah dari /stock-levels dan
  /// /stock-movements; ini menutup layar yang menyusun daftarnya dari master.
  Future<List<MaterialItem>> getMaterials() async {
    final res = await api.dio.get(
      '/materials',
      queryParameters: {'kind': 'semi_finished'},
    );
    debugPrint('[MaterialRepo] status=${res.statusCode} body=${res.data}');

    final data = res.data['data'];
    if (data == null || data is! List) return [];
    return data.map((e) => MaterialItem.fromJson(e)).toList();
  }
}
