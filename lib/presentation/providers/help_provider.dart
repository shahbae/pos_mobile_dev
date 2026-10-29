import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/help_ticket_model.dart';
import 'package:pos_mobile/data/repositories/help_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';

final helpRepositoryProvider = Provider<HelpRepository>((ref) {
  return HelpRepository(ref.watch(apiProvider));
});

final myHelpTicketsProvider = FutureProvider.autoDispose<List<HelpTicket>>((ref) {
  return ref.watch(helpRepositoryProvider).mine();
});

final helpCategoriesProvider = FutureProvider.autoDispose<List<HelpCategory>>((ref) {
  return ref.watch(helpRepositoryProvider).categories();
});
