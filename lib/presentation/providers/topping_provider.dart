import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/topping_model.dart';
import 'package:pos_mobile/data/repositories/topping_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';

final toppingRepositoryProvider = Provider<ToppingRepository>((ref) {
  return ToppingRepository(ref.watch(apiProvider));
});

/// Daftar topping aktif untuk dipakai di POS (picker topping).
final toppingListProvider = FutureProvider<List<Topping>>((ref) async {
  return ref.watch(toppingRepositoryProvider).getToppings(activeOnly: true);
});
