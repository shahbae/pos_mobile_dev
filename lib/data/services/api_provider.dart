import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/services/api_services.dart';

final apiProvider = Provider<ApiService>((ref) {
  return ApiService();
});
