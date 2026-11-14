import 'package:flutter/material.dart';
import 'package:pos_mobile/utils/currency.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/presentation/providers/expense_provider.dart';

/// Pilihan Jenis Biaya di form pengeluaran (Tahap 7, SPV-A7 & F-1.3). Wajib:
/// pengeluaran tanpa jenis tidak ikut dihitung KPI SPV maupun Finance.
/// Daftarnya dari server (`/cost-types`), hanya yang aktif. Jenis yang sudah
/// dinonaktifkan tetap tampil bila itu pilihan pengeluaran yang sedang diubah.
class CostTypeField extends ConsumerWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  final bool enabled;

  const CostTypeField({super.key, required this.value, required this.onChanged, this.enabled = true});

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
        final standard = [for (final t in shown) if (t.id == current) t.dailyStandard].firstOrNull;
        final field = DropdownButtonFormField<int>(
          key: const ValueKey('cost-type-field'),
          initialValue: current,
          isExpanded: true,
          decoration: decoration,
          items: [
            for (final t in shown)
              DropdownMenuItem(value: t.id, child: Text(t.isActive ? t.name : '${t.name} (nonaktif)')),
          ],
          validator: (v) => v == null ? 'Pilih jenis biaya' : null,
          onChanged: enabled ? onChanged : null,
        );
        if (standard == null) return field;
        // Revisi KPI 11 Nov (SPV-A7): lewat standar harian = menunggu ACC SPV.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            field,
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'Standar harian ${formatRupiah(standard)}. Kalau total jenis ini hari ini lewat dari itu, '
                'pengeluaran menunggu ACC SPV dulu.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ),
          ],
        );
      },
    );
  }
}
