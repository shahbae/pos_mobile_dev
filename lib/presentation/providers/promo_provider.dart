import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/promo_model.dart';
import 'package:pos_mobile/data/repositories/promo_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';

final promoRepositoryProvider = Provider<PromoRepository>((ref) {
  return PromoRepository(ref.watch(apiProvider));
});

/// Promo yang aktif hari ini, untuk dipakai saat checkout.
final activePromosProvider = FutureProvider<List<Promo>>((ref) async {
  return ref.watch(promoRepositoryProvider).getActivePromos();
});
