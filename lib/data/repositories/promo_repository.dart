import 'package:flutter/foundation.dart';
import '../services/api_services.dart';
import '../models/promo_model.dart';

class PromoRepository {
  final ApiService api;
  PromoRepository(this.api);

  /// Promo yang aktif hari ini (tidak perlu role khusus).
  Future<List<Promo>> getActivePromos() async {
    final res = await api.dio.get('/promos/active');

    debugPrint('[PromoRepo] status=${res.statusCode} body=${res.data}');

    final data = res.data['data'];
    if (data == null || data is! List) return [];

    return data.map((e) => Promo.fromJson(e)).toList();
  }
}
