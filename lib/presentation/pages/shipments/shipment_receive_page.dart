import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/shipment_model.dart';
import 'package:pos_mobile/presentation/pages/kpi/kpi_widgets.dart';
import 'package:pos_mobile/presentation/providers/shipment_provider.dart';
import 'package:pos_mobile/presentation/widgets/confirm_dialog.dart';
import 'package:pos_mobile/theme/app_theme.dart';

final _num = NumberFormat('#,##0.####', 'id_ID');

String _fmt(double v) => _num.format(v);

/// Menerima kiriman (Tahap 7, PRD-C2). Seluruh kiriman tetap diterima dalam
/// satu tekan, tapi tiap barang boleh diberi jumlah yang rusak atau
/// kedaluwarsa beserta fotonya. Bagian itu tidak masuk stok outlet dan
/// dihitung di KPI Produksi gudang pengirim.
///
/// Mengembalikan `true` lewat `pop` bila kiriman diterima.
class ShipmentReceivePage extends ConsumerStatefulWidget {
  final Shipment shipment;
  const ShipmentReceivePage({super.key, required this.shipment});

  @override
  ConsumerState<ShipmentReceivePage> createState() => _ShipmentReceivePageState();
}

class _ShipmentReceivePageState extends ConsumerState<ShipmentReceivePage> {
  late final List<ReceiveLineInput> _lines = [
    for (final l in widget.shipment.lines) ReceiveLineInput(line: l),
  ];

  /// Baris yang sedang dibuka isian rusaknya.
  final Set<int> _open = {};
  bool _busy = false;

  Future<void> _submit() async {
    final problems = receiveProblems(_lines);
    if (problems.isNotEmpty) {
      _snack(problems.first);
      return;
    }
    final damaged = _lines.where((l) => l.hasDamage).toList();
    final ok = await confirmAction(
      context,
      title: 'Terima kiriman ini?',
      message: damaged.isEmpty
          ? 'Semua barang masuk stok cabang sekarang juga. Ini tidak bisa dibatalkan.'
          : '${damaged.length} barang ada yang rusak/kedaluwarsa dan bagian itu TIDAK masuk stok. '
              'Sisanya masuk stok cabang sekarang juga. Ini tidak bisa dibatalkan.',
      confirmLabel: 'Ya, terima',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(shipmentRepositoryProvider)
          .receive(widget.shipment.id, revision: widget.shipment.revision, damage: _lines);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('$e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sh = widget.shipment;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final damagedCount = _lines.where((l) => l.hasDamage).length;
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: Text('Terima Kiriman #${sh.id}'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
            child: Text(
              'Hitung barangnya. Kalau ada yang rusak atau kedaluwarsa, ketuk barangnya, isi '
              'jumlahnya, dan foto. Bagian itu tidak masuk stok cabang.',
              style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _lines.length; i++) ...[
            _LineEditor(
              key: ValueKey(_lines[i].line.id),
              input: _lines[i],
              open: _open.contains(_lines[i].line.id),
              enabled: !_busy,
              onToggle: () => setState(() {
                final id = _lines[i].line.id;
                if (!_open.remove(id)) _open.add(id);
              }),
              onChanged: (v) => setState(() => _lines[i] = v),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.borderLight)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (damagedCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '$damagedCount barang ada yang rusak/kedaluwarsa',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w700),
                ),
              ),
            ElevatedButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: const Text('Terima Kiriman'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.borderLight,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineEditor extends StatefulWidget {
  final ReceiveLineInput input;
  final bool open;
  final bool enabled;
  final VoidCallback onToggle;
  final ValueChanged<ReceiveLineInput> onChanged;

  const _LineEditor({
    super.key,
    required this.input,
    required this.open,
    required this.enabled,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  State<_LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends State<_LineEditor> {
  final _damaged = TextEditingController();
  final _expired = TextEditingController();

  @override
  void dispose() {
    _damaged.dispose();
    _expired.dispose();
    super.dispose();
  }

  double _read(String raw) => double.tryParse(raw.trim().replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final d = widget.input;
    final l = d.line;
    final bad = d.exceeds || d.needsPhoto;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: bad ? Colors.red.shade300 : (d.hasDamage ? Colors.orange.shade300 : AppTheme.borderLight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.enabled ? widget.onToggle : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                          d.hasDamage
                              ? 'Masuk stok ${_fmt(d.acceptedBase)} ${l.unit} dari ${_fmt(l.qty)} ${l.unit}'
                              : 'Dikirim ${_fmt(d.shippedInInput)} ${d.inputUnit}'
                                  '${d.factor == 1 ? '' : ' (${_fmt(l.qty)} ${l.unit})'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: d.hasDamage ? Colors.orange.shade800 : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    widget.open ? 'Tutup' : (d.hasDamage ? 'Ubah' : 'Ada rusak?'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.brandBlue),
                  ),
                ],
              ),
            ),
          ),
          if (widget.open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: _qtyField('Rusak', _damaged, (v) => widget.onChanged(d.copyWith(damaged: v)))),
                      const SizedBox(width: 10),
                      Expanded(child: _qtyField('Kedaluwarsa', _expired, (v) => widget.onChanged(d.copyWith(expired: v)))),
                    ],
                  ),
                  if (d.exceeds) ...[
                    const SizedBox(height: 6),
                    Text('Melebihi yang dikirim (${_fmt(d.shippedInInput)} ${d.inputUnit}).',
                        style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                  ],
                  if (d.hasDamage) ...[
                    const SizedBox(height: 10),
                    if (d.photo != null)
                      KpiPhotoPreview(
                        d.photo!,
                        height: 140,
                        onRemove: widget.enabled ? () => widget.onChanged(d.copyWith(clearPhoto: true)) : null,
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: widget.enabled
                            ? () async {
                                final b = await pickKpiPhoto(context);
                                if (b != null) widget.onChanged(widget.input.copyWith(photo: b));
                              }
                            : null,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Foto barang yang rusak (wajib)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade300),
                        ),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _qtyField(String label, TextEditingController c, ValueChanged<double> onChanged) {
    return TextField(
      controller: c,
      enabled: widget.enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: '0',
        suffixText: widget.input.inputUnit,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onChanged: (v) => onChanged(_read(v)),
    );
  }
}
