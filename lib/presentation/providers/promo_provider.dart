import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/promo_model.dart';
import 'package:pos_mobile/data/repositories/promo_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_scope.dart';

final promoRepositoryProvider = Provider<PromoRepository>((ref) {
  // Ikut lahir ulang saat pindah cabang — lihat [branchScopeProvider].
  ref.watch(branchScopeProvider);
  return PromoRepository(ref.watch(apiProvider));
});

/// Promo yang aktif hari ini, untuk dipakai saat checkout.
///
/// `autoDispose` penting di sini: promo berganti tiap hari, sedangkan tablet
/// kasir bisa menyala berhari-hari tanpa app pernah di-restart. Tanpa ini
/// hasilnya (termasuk error) dipegang selamanya, sehingga promo hari kemarin
/// masih tampil dan promo hari ini tidak pernah muncul.
final activePromosProvider = FutureProvider.autoDispose<List<Promo>>((ref) async {
  return ref.watch(promoRepositoryProvider).getActivePromos();
});
