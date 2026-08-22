import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_mobile/data/models/leader_daily_report_model.dart';
import 'package:pos_mobile/presentation/providers/daily_report_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

class LeaderDailyReportPage extends ConsumerWidget {
  const LeaderDailyReportPage({super.key});

  /// Label rentang: satu hari → "03 Agu 2026", lebih → "01 – 03 Agu 2026".
  static String _rangeLabel(DateTimeRange range) {
    final fmt = DateFormat('dd MMM yyyy', 'id_ID');
    if (DateUtils.isSameDay(range.start, range.end)) {
      return fmt.format(range.start);
    }
    return "${fmt.format(range.start)} – ${fmt.format(range.end)}";
  }

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final current = ref.read(leaderDailyReportRangeProvider);
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: current,
    );
    if (picked == null) return;
    ref.read(leaderDailyReportRangeProvider.notifier).state = picked;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(leaderDailyReportRangeProvider);
    final reportAsync = ref.watch(leaderDailyReportProvider);
    final rangeLabel = _rangeLabel(range);
    final isToday = DateUtils.isSameDay(range.start, range.end) &&
        DateUtils.isSameDay(range.start, DateTime.now());

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text("Laporan Harian Leader"),
        backgroundColor: AppTheme.bgLight,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(leaderDailyReportProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _DateBranchCard(
              dateLabel: rangeLabel,
              caption: isToday ? "Hari Ini" : "Rentang Tanggal",
              branchName: reportAsync.valueOrNull?.branchName,
              onTap: () => _pickRange(context, ref),
            ),
            const SizedBox(height: 14),
            reportAsync.when(
              data: (data) {
                // Pakai rentang yang dipantulkan BE, bukan state lokal, supaya
                // baris shift selalu cocok dengan data yang benar-benar dimuat.
                final multiDay = data.isMultiDay;
                if (data.shifts.isEmpty) {
                  return _InfoCard(
                    title: "Belum ada shift",
                    message: multiDay
                        ? "Belum ada shift yang tercatat pada rentang ini."
                        : "Belum ada shift yang tercatat untuk tanggal ini.",
                  );
                }
                return Column(
                  children: [
                    if (data.chart.points.isNotEmpty) ...[
                      _TrafficChartCard(chart: data.chart),
                      const SizedBox(height: 12),
                    ],
                    for (final shift in data.shifts) ...[
                      _ShiftCard(shift: shift, showDate: multiDay),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 4),
                    _TotalsCard(totals: data.totals, multiDay: multiDay),
                  ],
                );
              },
              loading: () => const _Skeleton(),
              error: (e, _) => _ErrorCard(
                message: e.toString(),
                onRetry: () => ref.invalidate(leaderDailyReportProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Format selisih kas: `null` (shift masih buka) → "-", selain itu bertanda.
String _formatDifference(num? value) {
  if (value == null) return "-";
  if (value == 0) return formatRupiah(0);
  final sign = value > 0 ? "+" : "-";
  return "$sign${formatRupiah(value.abs())}";
}

/// Merah bila kurang, hijau bila lebih, netral bila pas / belum ada.
Color _differenceColor(num? value) {
  if (value == null || value == 0) return AppTheme.textPrimary;
  return value < 0 ? AppTheme.danger : AppTheme.brandGreenDark;
}

class _DateBranchCard extends StatelessWidget {
  final String dateLabel;
  final String caption;
  final String? branchName;
  final VoidCallback onTap;

  const _DateBranchCard({
    required this.dateLabel,
    required this.caption,
    required this.branchName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.brandBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.date_range_outlined,
                color: AppTheme.brandBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    caption,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (branchName != null && branchName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.store_outlined,
                          size: 13,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            branchName!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.edit_calendar_outlined,
              size: 20,
              color: AppTheme.brandBlue,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final LeaderShiftReport shift;

  /// Tampilkan tanggal shift — dipakai saat rentang mencakup lebih dari 1 hari.
  final bool showDate;

  const _ShiftCard({required this.shift, required this.showDate});

  /// "2026-08-03" → "03 Agu 2026"; kalau gagal parse, tampilkan apa adanya.
  String get _dateLabel {
    final parsed = DateTime.tryParse(shift.shiftDate);
    if (parsed == null) return shift.shiftDate;
    return DateFormat('dd MMM yyyy', 'id_ID').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shift.shiftName.isEmpty ? "Shift" : shift.shiftName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    if (showDate && shift.shiftDate.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _dateLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.brandBlue,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      "Kasir: ${shift.cashierName.isEmpty ? '-' : shift.cashierName}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(isOpen: shift.isOpen),
            ],
          ),
          const SizedBox(height: 14),
          // Metrik utama: penjualan & bersih.
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: "Total Penjualan",
                  value: formatRupiah(shift.totalSales),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: "Bersih",
                  value: formatRupiah(shift.net),
                  valueColor: shift.net < 0
                      ? AppTheme.danger
                      : AppTheme.brandGreenDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.borderLight),
          const SizedBox(height: 10),
          _line("Trafik", "${shift.transactionCount} transaksi"),
          _line("Item Terjual", "${shift.totalItems} item"),
          _line("Modal Awal", formatRupiah(shift.openingCash)),
          _line("Penjualan Tunai", formatRupiah(shift.cashSales)),
          _line("Penjualan QRIS", formatRupiah(shift.qrisSales)),
          _line("Pengeluaran", formatRupiah(shift.expenses)),
          const SizedBox(height: 6),
          const Divider(height: 1, color: AppTheme.borderLight),
          const SizedBox(height: 8),
          // Angka laci — rumusnya sama persis dengan GET /shifts (BE §2a).
          _line("Kas Seharusnya", formatRupiah(shift.expectedCash)),
          _line(
            "Kas Fisik (Tutup)",
            shift.closingCash == null ? "-" : formatRupiah(shift.closingCash!),
          ),
          _line(
            "Selisih",
            _formatDifference(shift.difference),
            valueColor: _differenceColor(shift.difference),
          ),
          if (shift.isOpen)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                "Shift masih buka — selisih dihitung setelah tutup.",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _line(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MetricTile({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isOpen;

  const _StatusChip({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? AppTheme.brandBlue : AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOpen ? "Buka" : "Tutup",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final LeaderDailyTotals totals;
  final bool multiDay;

  const _TotalsCard({required this.totals, required this.multiDay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.brandBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.brandBlue.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.summarize_outlined,
                color: AppTheme.brandBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                multiDay ? "Total Rentang" : "Total Harian",
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _line("Total Penjualan", formatRupiah(totals.totalSales)),
          _line("Total Item", "${totals.totalItems} item"),
          _line("Total Transaksi", "${totals.transactionCount} transaksi"),
          _line("Total Pengeluaran", formatRupiah(totals.expenses)),
          _line(
            multiDay ? "Total Cash" : "Total Cash (2 Shift)",
            formatRupiah(totals.totalCash),
          ),
          _line(
            multiDay ? "Total QRIS" : "Total QRIS (2 Shift)",
            formatRupiah(totals.totalQris),
          ),
          _line("Total Modal Awal", formatRupiah(totals.openingCash)),
          _line("Total Kas Seharusnya", formatRupiah(totals.expectedCash)),
          // BE hanya menjumlahkan shift yang sudah ditutup untuk dua baris ini.
          _line("Total Kas Fisik", formatRupiah(totals.closingCash)),
          _line(
            "Total Selisih",
            _formatDifference(totals.difference),
            valueColor: _differenceColor(totals.difference),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: AppTheme.borderLight),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Bersih",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                formatRupiah(totals.net),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: totals.net < 0
                      ? AppTheme.danger
                      : AppTheme.brandGreenDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Warna per shift (indeks = urutan kemunculan shift di grafik).
const _shiftColors = <Color>[
  AppTheme.brandBlue, // hijau — Shift 1
  Color(0xFF3B82F6), // biru — Shift 2
  Color(0xFFF59E0B), // amber — shift ke-3 (mis. middle)
  Color(0xFF8B5CF6), // ungu — cadangan
];

/// Rupiah ringkas untuk label sumbu-Y (mis. 410000 → "410rb", 1.5jt).
String _compactRp(num v) {
  if (v >= 1e9) {
    final n = v / 1e9;
    return "${n.toStringAsFixed(n % 1 == 0 ? 0 : 1)}M";
  }
  if (v >= 1e6) {
    final n = v / 1e6;
    return "${n.toStringAsFixed(n % 1 == 0 ? 0 : 1)}jt";
  }
  if (v >= 1e3) {
    return "${(v / 1e3).toStringAsFixed(0)}rb";
  }
  return v.toStringAsFixed(0);
}

/// Satu batang grafik (1 jam-bucket, 1 shift).
class _Bar {
  final double valueRatio; // 0..1 terhadap maxValue
  final Color color;
  final String timeLabel; // "HH:mm"
  final int shiftId;

  const _Bar({
    required this.valueRatio,
    required this.color,
    required this.timeLabel,
    required this.shiftId,
  });
}

class _TrafficChartCard extends StatelessWidget {
  final LeaderReportChart chart;

  const _TrafficChartCard({required this.chart});

  @override
  Widget build(BuildContext context) {
    final points = chart.points;
    if (points.isEmpty) return const SizedBox.shrink();

    // Nilai maksimum (sumbu-Y).
    num maxValue = 0;
    for (final p in points) {
      if (p.revenueTotal > maxValue) maxValue = p.revenueTotal;
    }
    if (maxValue <= 0) maxValue = 1;

    // Urutan shift (untuk warna + legenda konsisten).
    final order = <int>[];
    final names = <int, String>{};
    for (final p in points) {
      if (!names.containsKey(p.shiftId)) {
        order.add(p.shiftId);
        names[p.shiftId] = p.shiftName;
      }
    }
    Color colorForShift(int shiftId) {
      final i = order.indexOf(shiftId);
      return _shiftColors[(i < 0 ? 0 : i) % _shiftColors.length];
    }

    // Tiap titik = satu batang, diurut berdasarkan waktu (lalu shift).
    final sorted = [...points]
      ..sort((a, b) {
        final t = a.time.compareTo(b.time);
        return t != 0 ? t : a.shiftId.compareTo(b.shiftId);
      });
    final timeFmt = DateFormat('HH:mm', 'id_ID');
    final bars = [
      for (final p in sorted)
        _Bar(
          valueRatio: (p.revenueTotal / maxValue).clamp(0, 1).toDouble(),
          color: colorForShift(p.shiftId),
          timeLabel: timeFmt.format(p.time.toLocal()),
          shiftId: p.shiftId,
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Trafik Penjualan",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            "Penjualan per jam, dibedakan warna per shift",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 170,
            width: double.infinity,
            child: CustomPaint(
              painter: _BarChartPainter(
                bars: bars,
                maxValue: maxValue,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final id in order)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colorForShift(id),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      (names[id] ?? '').isEmpty ? "Shift $id" : names[id]!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<_Bar> bars;
  final num maxValue;

  const _BarChartPainter({required this.bars, required this.maxValue});

  @override
  void paint(Canvas canvas, Size size) {
    const gutterLeft = 46.0; // ruang label sumbu-Y (rupiah)
    const gutterBottom = 20.0; // ruang label sumbu-X (jam)
    const topPad = 8.0;

    final left = gutterLeft;
    final top = topPad;
    final right = size.width - 4.0;
    final bottom = size.height - gutterBottom;
    final w = (right - left).clamp(0.0, double.infinity);
    final h = (bottom - top).clamp(0.0, double.infinity);

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppTheme.borderLight.withOpacity(0.8);

    // Gridlines + label sumbu-Y (0, 1/3, 2/3, max).
    const divisions = 3;
    for (var i = 0; i <= divisions; i++) {
      final y = top + (h / divisions) * i;
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);

      final value = maxValue * (1 - i / divisions);
      final tp = _text(_compactRp(value), 9.5, AppTheme.textSecondary);
      tp.paint(
        canvas,
        Offset(left - 6 - tp.width, y - tp.height / 2),
      );
    }

    if (bars.isEmpty) return;

    // Layout batang: bagi lebar jadi n slot, tiap batang mengisi ~64% slot.
    final n = bars.length;
    final slotW = w / n;
    final barW = (slotW * 0.64).clamp(6.0, 34.0);

    // Label sumbu-X: kalau batang banyak, tampilkan sebagian biar tak berdempet.
    final labelEvery = (n / 6).ceil().clamp(1, n);

    for (var i = 0; i < n; i++) {
      final b = bars[i];
      final cx = left + slotW * i + slotW / 2;
      final barH = (h * b.valueRatio).clamp(b.valueRatio > 0 ? 3.0 : 0.0, h);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - barW / 2, bottom - barH, barW, barH),
        topLeft: const Radius.circular(5),
        topRight: const Radius.circular(5),
      );
      canvas.drawRRect(rect, Paint()..color = b.color);

      // Label jam di bawah batang.
      if (i % labelEvery == 0 || i == n - 1) {
        final tp = _text(b.timeLabel, 9.5, AppTheme.textSecondary);
        tp.paint(
          canvas,
          Offset(cx - tp.width / 2, bottom + 5),
        );
      }
    }
  }

  TextPainter _text(String s, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    return tp;
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    if (oldDelegate.maxValue != maxValue) return true;
    if (oldDelegate.bars.length != bars.length) return true;
    for (var i = 0; i < bars.length; i++) {
      final a = oldDelegate.bars[i];
      final b = bars[i];
      if (a.valueRatio != b.valueRatio ||
          a.color != b.color ||
          a.timeLabel != b.timeLabel) {
        return true;
      }
    }
    return false;
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String message;

  const _InfoCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Gagal memuat laporan",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandBlue,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Coba Lagi"),
            ),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 2; i++) ...[
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
