import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/shift_model.dart';
import 'package:pos_mobile/data/repositories/shift_repository.dart';

/// Shift kasir yang sedang aktif (null jika belum buka).
final currentShiftProvider = FutureProvider.autoDispose<ShiftModel?>((ref) async {
  return ref.watch(shiftRepositoryProvider).getCurrent();
});

/// Riwayat shift.
final shiftListProvider = FutureProvider.autoDispose<List<ShiftModel>>((ref) async {
  return ref.watch(shiftRepositoryProvider).list();
});
