import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/kpi_model.dart';
import 'package:pos_mobile/data/models/profile_model.dart';
import 'package:pos_mobile/presentation/pages/dashboard/menu_layout.dart';
import 'package:pos_mobile/presentation/pages/kpi/kpi_widgets.dart';
import 'package:pos_mobile/presentation/pages/profile/profile_page.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/kpi_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Foto profil bulat dengan lencana kamera (layout baru, revisi owner 26 Nov).
class ProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final double radius;
  final VoidCallback? onTap;
  const ProfileAvatar({super.key, this.photoUrl, this.radius = 38, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFFD1D5DB),
            foregroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
            child: Icon(Icons.person, size: radius * 1.2, color: Colors.white),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppTheme.brandGreenDark,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(Icons.photo_camera_outlined, size: radius * 0.38, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Crew 67,8 • Leader 88,5": skor KPI bulan ini per modul, warnanya mengikuti
/// predikat. Kosong bila akun ini tidak melihat KPI atau belum ada skor.
class KpiScoreLine extends ConsumerWidget {
  final bool center;
  final double fontSize;
  const KpiScoreLine({super.key, this.center = false, this.fontSize = 15});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canSeeOwnKpi(ref.watch(authProvider).held)) return const SizedBox.shrink();
    final scores = ref.watch(myKpiProvider(kpiPeriodOf(DateTime.now()))).valueOrNull?.scores ?? const [];
    final shown = scores.where((s) => s.score != null).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final spans = <InlineSpan>[];
    for (final s in shown) {
      if (spans.isNotEmpty) spans.add(const TextSpan(text: '  •  '));
      spans.add(TextSpan(text: '${kpiModuleLabels[s.module] ?? s.module} '));
      spans.add(TextSpan(
        text: kpiNum(s.score),
        style: TextStyle(color: s.predicate.isEmpty ? AppTheme.textPrimary : kpiPredicateColor(s.predicate)),
      ));
    }
    return Text.rich(
      TextSpan(children: spans),
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
    );
  }
}

/// Kartu profil di atas tab Profil: foto, nama, jabatan, skor KPI. Diketuk →
/// halaman Data diri.
class ProfileSummaryCard extends ConsumerWidget {
  const ProfileSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProfileModel? p = ref.watch(myProfileProvider).valueOrNull;
    final held = ref.watch(authProvider).held;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Row(
          children: [
            ProfileAvatar(photoUrl: p?.photoUrl),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p?.name ?? '…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    jobTitle(p?.roles.isNotEmpty == true ? p!.roles : held),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  const KpiScoreLine(),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
