import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/presentation/pages/dashboard/menu_layout.dart';
import 'package:pos_mobile/presentation/pages/dashboard/menu_tiles.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// "Tugas setiap hari" (layout baru, revisi owner 26 Nov 2026), dibuka dari
/// tab Laporan: Monitoring pesanan, Ceklis foto, Reminder, Setoran, Bantuan,
/// Arahan SPV, dan Sidak untuk SPV. Urutan di [dailyTaskMenu].
class DailyTasksPage extends ConsumerWidget {
  const DailyTasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Tugas Setiap Hari'), centerTitle: true),
      body: MenuList(keys: dailyTaskMenu(ref.watch(menuAccessProvider))),
    );
  }
}
