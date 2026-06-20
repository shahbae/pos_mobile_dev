import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/shift_model.dart';
import 'package:pos_mobile/data/repositories/shift_repository.dart';
import 'package:pos_mobile/presentation/pages/shifts/shift_page.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/shift_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Pastikan ada shift aktif sebelum membuka kasir / membuat transaksi.
///
/// BE mewajibkan shift terbuka untuk `POST /product-transactions`. Fungsi ini
/// cek `GET /shifts/current` lebih dulu; bila belum ada shift aktif, kasir
/// diarahkan ke halaman buka shift. Mengembalikan `true` bila boleh lanjut.
Future<bool> ensureActiveShift(BuildContext context, WidgetRef ref) async {
  // Role tanpa fitur shift (mis. Produksi) tidak perlu—dan tidak boleh—cek shift.
  if (!hasFeature(ref.read(authProvider).role, AppFeature.shift)) return true;

  final shift = await _fetchCurrentShift(context, ref);
  if (shift != null && shift.isOpen) return true;
  if (!context.mounted) return false;

  final goOpen = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Belum Ada Shift Aktif'),
      content: const Text(
        'Buka shift kasir terlebih dahulu sebelum memulai transaksi.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.brandBlue,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Buka Shift'),
        ),
      ],
    ),
  );
  if (goOpen != true || !context.mounted) return false;

  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ShiftPage()),
  );
  if (!context.mounted) return false;

  // Setelah kembali dari halaman shift, cek ulang apakah shift sudah dibuka.
  ref.invalidate(currentShiftProvider);
  final after = await _fetchCurrentShift(context, ref);
  return after != null && after.isOpen;
}

/// Ambil shift aktif sambil menampilkan loading singkat; null bila gagal/ kosong.
Future<ShiftModel?> _fetchCurrentShift(BuildContext context, WidgetRef ref) async {
  try {
    return await ref.read(shiftRepositoryProvider).getCurrent();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal memeriksa shift: $e'),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
      ));
    }
    return null;
  }
}
