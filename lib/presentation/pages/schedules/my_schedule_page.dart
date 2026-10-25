import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/attendance_model.dart';
import 'package:pos_mobile/data/models/schedule_model.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

final _dayLabel = DateFormat('EEEE, d MMMM', 'id_ID');

/// Jadwal saya (Tahap 1 SDM): hari ini sampai akhir bulan depan. Hanya bulan
/// yang sudah disetujui SPV yang dikirim server.
class MySchedulePage extends ConsumerWidget {
  const MySchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mySchedulesProvider);
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Jadwal Saya'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(mySchedulesProvider),
        child: async.when(
          loading: SdmStateView.loading,
          error: (e, _) => SdmStateView(
            icon: Icons.error_outline,
            message: '$e',
            onRetry: () => ref.invalidate(mySchedulesProvider),
          ),
          data: (rows) => _ScheduleList(rows: rows),
        ),
      ),
    );
  }
}

/// Baris dikelompokkan per tanggal, mulai hari ini. Dobel shift = dua baris di
/// satu tanggal, sudah urut jam mulai dari server.
List<MapEntry<String, List<MyScheduleEntry>>> groupFromToday(
    List<MyScheduleEntry> rows, String today) {
  final byDate = <String, List<MyScheduleEntry>>{};
  for (final r in rows) {
    if (r.date.compareTo(today) < 0) continue;
    byDate.putIfAbsent(r.date, () => []).add(r);
  }
  final keys = byDate.keys.toList()..sort();
  return [for (final k in keys) MapEntry(k, byDate[k]!)];
}

class _ScheduleList extends StatelessWidget {
  final List<MyScheduleEntry> rows;
  const _ScheduleList({required this.rows});

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final days = groupFromToday(rows, today);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
      children: [
        const SdmNote(
          icon: Icons.info_outline,
          text: 'Yang tampil hanya jadwal bulan yang sudah disetujui SPV. Perubahan '
              'hari ini dari leader langsung terlihat setelah muat ulang.',
        ),
        const SizedBox(height: 16),
        if (days.isEmpty)
          const SdmEmpty(
            icon: Icons.event_busy_outlined,
            message: 'Belum ada jadwal yang disetujui untuk hari ini dan seterusnya.',
          ),
        for (final d in days) ...[
          _DayCard(date: d.key, entries: d.value, isToday: d.key == today),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  final String date;
  final List<MyScheduleEntry> entries;
  final bool isToday;
  const _DayCard({required this.date, required this.entries, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(date);
    return SdmCard(
      color: isToday ? AppTheme.brandBlue.withValues(alpha: 0.06) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(parsed == null ? date : _dayLabel.format(parsed),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
              ),
              if (isToday) const SdmPill('Hari ini', color: AppTheme.brandGreenDark),
            ],
          ),
          for (final e in entries) ...[
            const SizedBox(height: 10),
            _EntryRow(entry: e),
          ],
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final MyScheduleEntry entry;
  const _EntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final code = entry.shiftCode;
    if (!code.isWork) {
      return Row(
        children: [
          const Icon(Icons.beach_access_outlined, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Text(code.name,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
        ],
      );
    }
    final title = [
      code.name,
      if (entry.duty != null) ScheduleDuty.label(entry.duty),
      if (code.hours.isNotEmpty) code.hours,
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.work_outline, size: 20, color: AppTheme.brandGreenDark),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              if (entry.location.name.isNotEmpty)
                Text(entry.location.name,
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
