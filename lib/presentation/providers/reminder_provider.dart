import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/reminder_model.dart';
import 'package:pos_mobile/data/repositories/reminder_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository(ref.watch(apiProvider));
});

/// Reminder yang belum dibalas. Tidak autoDispose: spanduk di Dashboard
/// memakainya terus, dan `PushBinder` menyegarkannya tiap app kembali ke
/// depan atau notifikasi masuk.
final pendingRemindersProvider = FutureProvider<MyReminderPage>((ref) {
  return ref.watch(reminderRepositoryProvider).pending();
});

final reminderHistoryProvider = FutureProvider.autoDispose<MyReminderPage>((ref) {
  return ref.watch(reminderRepositoryProvider).history();
});

/// Segarkan semua daftar reminder sesudah sesuatu berubah.
void refreshReminders(WidgetRef ref) {
  ref.invalidate(pendingRemindersProvider);
  ref.invalidate(reminderHistoryProvider);
}
