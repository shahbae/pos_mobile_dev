import 'package:flutter/foundation.dart';
import '../services/api_services.dart';
import '../models/topping_model.dart';

class ToppingRepository {
  final ApiService api;
  ToppingRepository(this.api);

  /// Ambil daftar topping. Default hanya yang aktif (untuk dipakai di POS).
  Future<List<Topping>> getToppings({bool activeOnly = true}) async {
    final res = await api.dio.get('/toppings');

    debugPrint('[ToppingRepo] status=${res.statusCode} body=${res.data}');

    final data = res.data['data'];
    if (data == null || data is! List) return [];

    final list = data.map((e) => Topping.fromJson(e)).toList();
    return activeOnly ? list.where((t) => t.isActive).toList() : list;
  }
}
