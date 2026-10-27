import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/payroll_model.dart';
import 'package:pos_mobile/presentation/pages/payroll/my_loans_page.dart';
import 'package:pos_mobile/presentation/pages/payroll/payslip_list_page.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

/// Potongan bersama halaman Slip Gaji & Pinjaman (Tahap 2 SDM).

final _dayMonthYear = DateFormat('d MMMM yyyy', 'id_ID');
final _dayMonth = DateFormat('d MMM', 'id_ID');
final _monthYear = DateFormat('MMMM yyyy', 'id_ID');
final _dateTime = DateFormat('d MMM yyyy, HH.mm', 'id_ID');

DateTime? _parseYmd(String? ymd) => ymd == null || ymd.isEmpty ? null : DateTime.tryParse(ymd);

/// "2026-11-27" → "27 November 2026".
String payrollDate(String? ymd) {
  final d = _parseYmd(ymd);
  return d == null ? '-' : _dayMonthYear.format(d);
}

/// Nama slip: gajian 27 November 2026 → "November 2026".
String paydayMonth(String? ymd) {
  final d = _parseYmd(ymd);
  return d == null ? '-' : _monthYear.format(d);
}

/// "27 Okt – 26 Nov 2026".
String periodRange(String from, String to) {
  final a = _parseYmd(from);
  final b = _parseYmd(to);
  if (a == null || b == null) return '-';
  final head = a.year == b.year ? _dayMonth.format(a) : _dayMonthYear.format(a);
  return '$head – ${_dayMonthYear.format(b)}';
}

String payrollDateTime(DateTime? t) => t == null ? '-' : _dateTime.format(t);

/// Warna status pinjaman: kuning menunggu orang lain, hijau selesai baik,
/// merah ditolak, abu-abu dibatalkan.
Color loanStatusColor(String status) => switch (status) {
      'requested' || 'checked' || 'approved' => const Color(0xFFD97706),
      'awaiting_cash' => const Color(0xFF2563EB),
      'disbursed' => AppTheme.brandGreenDark,
      'rejected' => AppTheme.danger,
      _ => AppTheme.textSecondary,
    };

/// Satu baris penghasilan atau potongan, dengan lampiran yang bisa dibuka.
class PayslipLineTile extends StatefulWidget {
  final PayslipLine line;
  const PayslipLineTile({super.key, required this.line});

  @override
  State<PayslipLineTile> createState() => _PayslipLineTileState();
}

class _PayslipLineTileState extends State<PayslipLineTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = widget.line;
    final meta = [
      if (l.quantity != null && l.rate != null) '${l.quantity} ${l.unit.isEmpty ? '×' : l.unit} × ${formatRupiah(l.rate!)}',
      if (l.note.isNotEmpty) l.note,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(l.label,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              ),
              const SizedBox(width: 12),
              Text(formatRupiah(l.amount),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(meta, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
          ],
          if (l.details.isNotEmpty) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_open ? Icons.expand_less : Icons.expand_more, size: 18, color: AppTheme.brandGreenDark),
                    Text('Rincian (${l.details.length})',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.brandGreenDark)),
                  ],
                ),
              ),
            ),
            if (_open)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.bgLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final d in l.details)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 92,
                              child: Text(payrollDate(d.date),
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                            ),
                            Expanded(
                              child: Text(d.description,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            ),
                            if (d.amount != null)
                              Text(formatRupiah(d.amount!),
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Pintu ke Slip Gaji & Pinjaman dari layar yang terkunci absensi (belum absen
/// masuk, sudah absen pulang) dan dari layar utama finance. Slip terbit tanggal
/// 27 dan biasanya dibuka di luar jam kerja, jadi tidak boleh ikut terkunci.
class PayrollMenuButton extends StatelessWidget {
  const PayrollMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Slip gaji & pinjaman',
      icon: const Icon(Icons.receipt_long_outlined),
      onSelected: (v) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => v == 'slip' ? const PayslipListPage() : const MyLoansPage(),
        ),
      ),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'slip',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.receipt_long_outlined),
            title: Text('Slip Gaji'),
          ),
        ),
        PopupMenuItem(
          value: 'loan',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.payments_outlined),
            title: Text('Pinjaman'),
          ),
        ),
      ],
    );
  }
}
