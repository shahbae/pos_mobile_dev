import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/utils/currency_input_formatter.dart';
import 'package:pos_mobile/data/models/discount_reason_model.dart';
import 'package:pos_mobile/presentation/providers/product_transaction_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

/// Isi diskon manual (PRD F9): persen atau rupiah, dengan alasan wajib, tidak
/// lebih dari batas akun ini. Batas rupiah = persen batas × [subtotal].
/// Mengembalikan diskon yang dipilih, atau null bila dibatalkan.
Future<ManualDiscount?> showManualDiscountSheet(
  BuildContext context, {
  required int subtotal,
  required int limitPct,
  required List<DiscountReason> reasons,
  ManualDiscount? initial,
}) {
  return showModalBottomSheet<ManualDiscount>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _DiscountSheet(
      subtotal: subtotal,
      limitPct: limitPct,
      reasons: reasons,
      initial: initial,
    ),
  );
}

class _DiscountSheet extends StatefulWidget {
  final int subtotal;
  final int limitPct;
  final List<DiscountReason> reasons;
  final ManualDiscount? initial;

  const _DiscountSheet({
    required this.subtotal,
    required this.limitPct,
    required this.reasons,
    this.initial,
  });

  @override
  State<_DiscountSheet> createState() => _DiscountSheetState();
}

class _DiscountSheetState extends State<_DiscountSheet> {
  late bool _percent = widget.initial?.isPercent ?? true;
  late final TextEditingController _value = TextEditingController(
    text: widget.initial == null ? '' : NumberFormat.decimalPattern('id_ID').format(widget.initial!.value),
  );
  late int? _reasonId = widget.reasons.any((r) => r.id == widget.initial?.reasonId) ? widget.initial!.reasonId : null;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  int get _input => int.tryParse(_value.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  int get _limitAmount => widget.subtotal * widget.limitPct ~/ 100;

  /// Potongan rupiah yang akan dipasang, dengan pembulatan yang sama dengan
  /// server (persen dibulatkan ke bawah).
  int get _amount => _percent ? widget.subtotal * _input ~/ 100 : _input;

  String? get _problem {
    if (_input <= 0) return null;
    if (_percent) {
      if (_input > widget.limitPct) return 'Melebihi batas akunmu ${widget.limitPct}%';
    } else if (_input > _limitAmount) {
      return 'Melebihi batas akunmu ${widget.limitPct}% (${formatRupiah(_limitAmount)})';
    }
    return null;
  }

  bool get _valid => _input > 0 && _problem == null && _reasonId != null;

  void _save() {
    final reason = widget.reasons.firstWhere((r) => r.id == _reasonId);
    Navigator.pop(
      context,
      ManualDiscount(
        kind: _percent ? 'percent' : 'amount',
        value: _input,
        reasonId: reason.id,
        reasonName: reason.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppTheme.borderLight, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text("Diskon Manual", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              "Batas akunmu ${widget.limitPct}% dari subtotal ${formatRupiah(widget.subtotal)} "
              "(${formatRupiah(_limitAmount)}). Tidak bisa digabung dengan promo.",
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text("Persen")),
                ButtonSegment(value: false, label: Text("Rupiah")),
              ],
              selected: {_percent},
              onSelectionChanged: (v) => setState(() {
                _percent = v.first;
                _value.clear();
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('discount-value'),
              controller: _value,
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: _percent
                  ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)]
                  : [CurrencyInputFormatter()],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixText: _percent ? null : "Rp ",
                suffixText: _percent ? "%" : null,
                hintText: "0",
                helperText: _input > 0 && problem == null ? "Potongan ${formatRupiah(_amount)}" : null,
                errorText: problem,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            const Text("Alasan", style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in widget.reasons)
                  ChoiceChip(
                    label: Text(r.name),
                    selected: _reasonId == r.id,
                    onSelected: (_) => setState(() => _reasonId = r.id),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _valid ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(_input > 0 ? "Pasang diskon ${formatRupiah(_amount)}" : "Pasang diskon"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
