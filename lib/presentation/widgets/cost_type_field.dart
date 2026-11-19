import 'package:flutter/material.dart';
import 'package:pos_mobile/utils/currency.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/expense_model.dart';
import 'package:pos_mobile/presentation/providers/expense_provider.dart';

/// Pilihan Jenis Biaya di form pengeluaran (Tahap 7, SPV-A7 & F-1.3). Wajib:
/// pengeluaran tanpa jenis tidak ikut dihitung KPI SPV maupun Finance.
/// Daftarnya dari server (`/cost-types`), hanya yang aktif. Jenis yang sudah
/// dinonaktifkan tetap tampil bila itu pilihan pengeluaran yang sedang diubah.
///
/// Revisi 19 Nov: pilihan dikelompokkan Grup A (batas harian) dan Grup B
/// (batas bulanan). Setelah jenis dipilih, tampil pemakaian grupnya dan
/// perkiraan status dari nominal di [amountController]: langsung disetujui,
/// atau menunggu ACC SPV karena lewat batas persen omzet.
class CostTypeField extends ConsumerWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  final bool enabled;

  /// Nominal yang sedang diketik, untuk perkiraan status. Null = tanpa perkiraan.
  final TextEditingController? amountController;

  /// Saat mengubah pengeluaran: nominal & grup lamanya. Server sudah
  /// menghitungnya di pemakaian grup, jadi dikurangkan dulu.
  final double replacingAmount;
  final String replacingGroup;

  const CostTypeField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.amountController,
    this.replacingAmount = 0,
    this.replacingGroup = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final async = ref.watch(costTypesProvider);
    final decoration = InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      hintText: 'Pilih jenis biaya',
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary, width: 1.6)),
    );
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Row(
        children: [
          Expanded(child: Text('$e', style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626)))),
          TextButton(onPressed: () => ref.invalidate(costTypesProvider), child: const Text('Muat ulang')),
        ],
      ),
      data: (types) {
        final shown = [
          for (final t in types)
            if (t.isActive || t.id == value) t,
        ];
        final current = shown.any((t) => t.id == value) ? value : null;
        final selected = [for (final t in shown) if (t.id == current) t].firstOrNull;
        final daily = [for (final t in shown) if (t.isDailyGroup) t];
        final monthly = [for (final t in shown) if (!t.isDailyGroup) t];
        DropdownMenuItem<int> item(CostType t) =>
            DropdownMenuItem(value: t.id, child: Text(t.isActive ? t.name : '${t.name} (nonaktif)'));
        final field = DropdownButtonFormField<int>(
          key: const ValueKey('cost-type-field'),
          initialValue: current,
          isExpanded: true,
          decoration: decoration,
          // Judul grup memakai nilai negatif yang tidak bisa dipilih.
          selectedItemBuilder: (context) => [
            if (daily.isNotEmpty) const SizedBox.shrink(),
            for (final t in daily) _selectedLabel(t),
            if (monthly.isNotEmpty) const SizedBox.shrink(),
            for (final t in monthly) _selectedLabel(t),
          ],
          items: [
            if (daily.isNotEmpty) _header(-1, 'Grup A · batas harian'),
            for (final t in daily) item(t),
            if (monthly.isNotEmpty) _header(-2, 'Grup B · batas bulanan'),
            for (final t in monthly) item(t),
          ],
          validator: (v) => v == null ? 'Pilih jenis biaya' : null,
          onChanged: enabled
              ? (v) {
                  if (v != null && v > 0) onChanged(v);
                }
              : null,
        );
        if (selected == null) return field;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            field,
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _LimitHint(
                group: selected.expenseGroup,
                amountController: amountController,
                replacing: replacingGroup == selected.expenseGroup ? replacingAmount : 0,
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _selectedLabel(CostType t) => Align(
        alignment: Alignment.centerLeft,
        child: Text(t.isActive ? t.name : '${t.name} (nonaktif)', overflow: TextOverflow.ellipsis),
      );

  static DropdownMenuItem<int> _header(int id, String label) => DropdownMenuItem<int>(
        value: id,
        enabled: false,
        child: Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: .3)),
      );
}

/// Pemakaian grup hari ini/bulan ini dan perkiraan status nominal yang diketik.
class _LimitHint extends ConsumerWidget {
  final String group;
  final TextEditingController? amountController;
  final double replacing;

  const _LimitHint({required this.group, required this.amountController, required this.replacing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daily = group == expenseGroupDaily;
    final preview = ref.watch(expenseLimitProvider).valueOrNull;
    const muted = TextStyle(fontSize: 12, color: Color(0xFF6B7280));
    if (preview == null) {
      return Text(
        daily
            ? 'Grup A: batas harian persen omzet hari ini. Lewat batas = menunggu ACC SPV.'
            : 'Grup B: batas bulanan persen omzet. Lewat batas = menunggu ACC SPV.',
        style: muted,
      );
    }
    final rule = daily
        ? 'Grup A · batas ${_pct(preview.dailyPct)} omzet hari ini'
        : 'Grup B · batas ${_pct(preview.monthlyPct)} omzet ${preview.monthlyBasis == 'target' ? 'target bulan ini' : 'bulan berjalan'}';
    Widget body(double amount) {
      final p = preview.project(group, amount, replacing: replacing);
      final over = p.overLimit;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rule, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          const SizedBox(height: 2),
          Text(
            '${daily ? 'Hari ini' : 'Bulan ini'} ${formatRupiah(p.used)} dari batas ${formatRupiah(p.pagu)}.',
            style: muted,
          ),
          if (amount > 0) ...[
            const SizedBox(height: 6),
            Container(
              key: const ValueKey('expense-limit-projection'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: over ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: over ? const Color(0xFFFCD34D) : const Color(0xFFBBF7D0)),
              ),
              child: Text(
                over
                    ? 'Perkiraan: menunggu ACC SPV (${formatRupiah(p.accum)} > ${formatRupiah(p.pagu)}). '
                        '${daily ? 'Dinilai ulang tiap ada pengeluaran Grup A dan pukul ${preview.cutoffHour}.00; kalau omzet sudah cukup, lolos sendiri.' : 'Dinilai ulang tiap ada pengeluaran Grup B dan pukul ${preview.cutoffHour}.00.'}'
                    : 'Perkiraan: langsung disetujui (${formatRupiah(p.accum)} dari ${formatRupiah(p.pagu)}).',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: over ? const Color(0xFF92400E) : const Color(0xFF166534)),
              ),
            ),
          ],
        ],
      );
    }

    final ctrl = amountController;
    if (ctrl == null) return body(0);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (context, v, _) => body(double.tryParse(v.text.replaceAll('.', '').replaceAll(',', '')) ?? 0),
    );
  }

  static String _pct(double v) {
    final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
    return '${s.replaceAll('.', ',')}%';
  }
}
