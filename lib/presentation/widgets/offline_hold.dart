import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/presentation/pages/offline/offline_queue_page.dart';
import 'package:pos_mobile/presentation/providers/offline_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Tahan sebuah tindakan selama masih ada penjualan offline yang belum
/// terkirim.
///
/// Penjualan itu hanya ada di HP ini. Tutup shift akan menghitung kas tanpa
/// mereka; logout, pindah cabang, dan memasang pembaruan bisa membuat mereka
/// terkirim atas nama yang salah atau tidak terkirim sama sekali. Jadi
/// tindakannya menunggu sampai antrean kosong.
///
/// [action] adalah nama tindakannya untuk pesan, mis. "Tutup shift".
/// Mengembalikan true bila boleh dilanjutkan.
Future<bool> ensureNothingUnsent(BuildContext context, WidgetRef ref, {required String action}) async {
  int pending;
  try {
    pending = await ref.read(outboxStoreProvider).pendingAnywhere();
  } catch (_) {
    // DB lokal tak terbaca: tidak ada yang bisa ditunggu, jangan mengunci HP.
    return true;
  }
  if (pending == 0) return true;
  if (!context.mounted) return false;

  final open = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Masih Ada yang Belum Terkirim'),
      content: Text(
        '$pending penjualan offline belum terkirim ke server. $action ditahan sampai '
        'semuanya terkirim, supaya tidak ada penjualan yang hilang.\n\n'
        'Sambungkan HP ke jaringan, lalu tekan "Kirim sekarang".',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tutup')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.brandBlue,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Lihat'),
        ),
      ],
    ),
  );
  if (open == true && context.mounted) {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const OfflineQueuePage()));
  }
  return false;
}
