import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/sop_model.dart';
import 'package:pos_mobile/data/repositories/sop_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';

final sopRepositoryProvider = Provider<SopRepository>((ref) => SopRepository(ref.watch(apiProvider)));

final sopListProvider = FutureProvider.autoDispose<List<Sop>>((ref) => ref.watch(sopRepositoryProvider).list());
