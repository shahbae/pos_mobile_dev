import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/kpi_model.dart';
import 'package:pos_mobile/presentation/pages/kpi/photo_checklist_page.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/kpi_provider.dart';

/// Kartu Beranda "ceklis foto perlu dikirim" (Tahap 6). Tampil hanya bila
/// ada butir yang fasenya sedang terbuka dan belum terkirim (atau ditolak).
/// Dimuat ulang saat app kembali dibuka dan tiap 5 menit selama terlihat,
/// karena fase closing baru dibuka pada jam mulai shift.
class PhotoChecklistCard extends ConsumerStatefulWidget {
  const PhotoChecklistCard({super.key});

  @override
  ConsumerState<PhotoChecklistCard> createState() => _PhotoChecklistCardState();
}

class _PhotoChecklistCardState extends ConsumerState<PhotoChecklistCard> with WidgetsBindingObserver {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tick = Timer.periodic(const Duration(minutes: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    if (mounted && canUsePhotoChecklist(ref.read(authProvider).held)) ref.invalidate(myChecklistProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (!canUsePhotoChecklist(ref.watch(authProvider).held)) return const SizedBox.shrink();
    final sets = ref.watch(myChecklistProvider).valueOrNull ?? const <ChecklistSet>[];
    final s = ChecklistSummary.of(sets, now: DateTime.now());
    if (s.toSend == 0) return const SizedBox.shrink();

    final rejected = s.rejected > 0;
    final color = rejected ? const Color(0xFFB91C1C) : const Color(0xFFD97706);
    final title = rejected
        ? '${s.rejected} foto ceklis ditolak, kirim ulang'
        : '${s.toSend} foto ceklis perlu dikirim';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const PhotoChecklistPage()));
            _refresh();
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.photo_camera_outlined, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: color)),
                      const SizedBox(height: 2),
                      Text(
                        s.names.join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pengingat ceklis closing sebelum Tutup Shift (Tahap 6, C5.4a). Tidak
/// memblokir: server tidak menolak Tutup Shift karena ceklis, dan foto
/// "Laporan POS" bisa saja baru ada sesudah shift ditutup. Batas kirimnya
/// batas absen pulang, jadi kartu Beranda tetap mengingatkan sesudahnya.
///
/// Gagal memuat (mis. jaringan sesaat) = lanjut tanpa pengingat.
Future<void> remindClosingChecklist(BuildContext context, WidgetRef ref) async {
  if (!canUsePhotoChecklist(ref.read(authProvider).held)) return;
  List<ChecklistSet> sets;
  try {
    sets = await ref.read(kpiRepositoryProvider).myChecklist();
  } catch (_) {
    return;
  }
  final s = ChecklistSummary.of(
    sets,
    now: DateTime.now(),
    phase: 'closing',
    branchId: ref.read(authProvider).branchId,
  );
  if (s.toSend == 0 || !context.mounted) return;

  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Ceklis closing belum lengkap'),
      content: Text(
        'Belum terkirim: ${s.names.join(', ')}.\n\n'
        'Foto yang tidak ada sampai batas kirim mengurangi KPI semua kasir shift ini. '
        'Bisa dikirim sekarang atau sesudah shift ditutup.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nanti')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Foto sekarang'),
        ),
      ],
    ),
  );
  if (go == true && context.mounted) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PhotoChecklistPage(focusPhase: 'closing')),
    );
    ref.invalidate(myChecklistProvider);
  }
}
