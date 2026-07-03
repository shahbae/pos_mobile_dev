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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(leaderDailyReportDateProvider);
    final reportAsync = ref.watch(leaderDailyReportProvider);
    final fmt = DateFormat('dd MMM yyyy', 'id_ID');

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
            reportAsync.when(
              data: (data) => _DateBranchCard(
                dateLabel: fmt.format(date),
                branchName: data.branchName,
              ),
              loading: () => _DateBranchCard(
                dateLabel: fmt.format(date),
                branchName: null,
              ),
              error: (_, _) => _DateBranchCard(
                dateLabel: fmt.format(date),
                branchName: null,
              ),
            ),
            const SizedBox(height: 14),
            reportAsync.when(
              data: (data) {
                if (data.shifts.isEmpty) {
                  return _InfoCard(
                    title: "Belum ada shift",
                    message:
                        "Belum ada shift yang tercatat untuk tanggal ini.",
                  );
                }
                return Column(
                  children: [
                    if (data.chart.points.isNotEmpty) ...[
                      _TrafficChartCard(chart: data.chart),
                      const SizedBox(height: 12),
                    ],
                    for (final shift in data.shifts) ...[
                      _ShiftCard(shift: shift),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 4),
                    _TotalsCard(totals: data.totals),
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

class _DateBranchCard extends StatelessWidget {
  final String dateLabel;
  final String? branchName;

  const _DateBranchCard({required this.dateLabel, required this.branchName});

  @override
  Widget build(BuildContext context) {
    return Container(
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
                const Text(
                  "Hari Ini",
                  style: TextStyle(
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
        ],
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final LeaderShiftReport shift;

  const _ShiftCard({required this.shift});

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
          _line("Pengeluaran", formatRupiah(shift.expenses)),
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
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
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
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

  const _TotalsCard({required this.totals});

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
              const Text(
                "Total Harian",
                style: TextStyle(
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
          _line("Total Cash (2 Shift)", formatRupiah(totals.totalCash)),
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

  Widget _line(String label, String value) {
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
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
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
