import 'package:flutter/foundation.dart';
import '../services/api_services.dart';
import '../models/material_model.dart';

class MaterialRepository {
  final ApiService api;
  MaterialRepository(this.api);

  Future<List<MaterialItem>> getMaterials() async {
    final res = await api.dio.get('/materials');
    debugPrint('[MaterialRepo] status=${res.statusCode} body=${res.data}');

    final data = res.data['data'];
    if (data == null || data is! List) return [];
    return data.map((e) => MaterialItem.fromJson(e)).toList();
  }
}
