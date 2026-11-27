import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/presentation/pages/dashboard/menu_layout.dart';
import 'package:pos_mobile/presentation/pages/dashboard/menu_tiles.dart';

/// Tab Laporan (layout baru, revisi owner 26 Nov 2026). Urutan di [reportMenu];
/// kartu pertamanya membuka halaman Tugas setiap hari.
class ReportTab extends ConsumerWidget {
  const ReportTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MenuList(keys: reportMenu(ref.watch(menuAccessProvider)));
  }
}
