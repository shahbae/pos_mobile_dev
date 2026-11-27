import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/presentation/pages/dashboard/menu_layout.dart';
import 'package:pos_mobile/presentation/pages/dashboard/menu_tiles.dart';
import 'package:pos_mobile/presentation/pages/profile/profile_summary.dart';
import 'package:pos_mobile/presentation/providers/allowance_provider.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/kpi_provider.dart';

/// Tab Profil (layout baru, revisi owner 26 Nov 2026): kartu profil → Data
/// diri, lalu Jatah minum, Skor KPI, Jadwal saya, Absensi, Izin keluar, Slip
/// gaji, Pinjaman, Pinjaman Tunai, SOP. Urutan di [profileMenu].
class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myProfileProvider);
        ref.invalidate(myAllowanceProvider);
        ref.invalidate(myKpiProvider);
      },
      child: MenuList(
        header: const [ProfileSummaryCard()],
        keys: profileMenu(ref.watch(menuAccessProvider)),
      ),
    );
  }
}
