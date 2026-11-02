import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/stock_audit_model.dart';
import 'package:pos_mobile/presentation/providers/stock_audit_provider.dart';
import 'stock_audit_detail_page.dart';
import 'stock_audit_form_page.dart';

/// Opname harian sebelum Shift 2 ditutup (Tahap 5, PRD F13).
///
/// Dicek sebelum kasir mengetik kas akhir, supaya tidak ditolak sesudahnya.
/// true = boleh lanjut menutup shift. Gagal membaca status (mis. jaringan
/// sesaat) juga lanjut: server tetap menolak dengan `daily_audit_required`,
/// dan pemanggil memanggil [showDailyAuditRequired] untuk balasan itu.
Future<bool> ensureDailyAudit(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(stockAuditRepositoryProvider);
  AuditPeriods periods;
  try {
    periods = await repo.getPeriods();
  } catch (_) {
    return true;
  }
  var block = dailyAuditBlock(periods);
  if (block == DailyAuditBlock.none) return true;
  if (!context.mounted) return false;

  final go = await _askDailyAudit(context, block);
  if (go != true || !context.mounted) return false;
  await _openDailyAudit(context, periods.of(AuditTypes.daily)!);
  ref.invalidate(auditPeriodsProvider);

  // Sesudah kembali: lanjut ke kas akhir bila opname harian sudah lengkap.
  try {
    block = dailyAuditBlock(await repo.getPeriods());
  } catch (_) {
    return true;
  }
  if (block != DailyAuditBlock.none && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(block == DailyAuditBlock.missing
          ? 'Opname harian belum disimpan. Shift 2 belum bisa ditutup.'
          : 'Masih ada barang tidak wajar tanpa alasan. Shift 2 belum bisa ditutup.'),
      behavior: SnackBarBehavior.floating,
    ));
  }
  return block == DailyAuditBlock.none;
}

/// Server menolak menutup Shift 2 (`daily_audit_required`): tawarkan
/// membuka opname harian. Kasir lalu menekan Tutup Shift lagi.
Future<void> showDailyAuditRequired(BuildContext context, WidgetRef ref) async {
  AuditPeriods? periods;
  try {
    periods = await ref.read(stockAuditRepositoryProvider).getPeriods();
  } catch (_) {}
  if (!context.mounted) return;
  final daily = periods?.of(AuditTypes.daily);
  final block = periods == null ? DailyAuditBlock.missing : dailyAuditBlock(periods);
  final go = await _askDailyAudit(context, block == DailyAuditBlock.none ? DailyAuditBlock.missing : block);
  if (go == true && context.mounted && daily != null) {
    await _openDailyAudit(context, daily);
    ref.invalidate(auditPeriodsProvider);
  }
}

Future<bool?> _askDailyAudit(BuildContext context, DailyAuditBlock block) {
  final missing = block == DailyAuditBlock.missing;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(missing ? 'Opname harian dulu' : 'Lengkapi alasan opname harian'),
      content: Text(missing
          ? 'Shift 2 baru bisa ditutup sesudah opname harian hari ini disimpan. '
              'Timbang barangnya sekarang.'
          : 'Ada barang tidak wajar di opname harian hari ini yang belum diberi alasan. '
              'Lengkapi dulu sebelum menutup Shift 2.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nanti')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(missing ? 'Buka opname harian' : 'Lengkapi alasan'),
        ),
      ],
    ),
  );
}

Future<void> _openDailyAudit(BuildContext context, AuditPeriod daily) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => daily.auditId != null
          ? StockAuditDetailPage(auditId: daily.auditId!)
          : const StockAuditFormPage(auditType: AuditTypes.daily),
    ),
  );
}
