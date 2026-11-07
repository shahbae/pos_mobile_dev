import 'package:flutter/material.dart';

import 'package:pos_mobile/data/models/stock_audit_model.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Angka tampilan tanpa nol di belakang ("60.0" → "60").
String fmtAuditQty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toString();

String fmtAuditQtyUnit(double? q, String unit) {
  if (q == null) return '-';
  return unit.isEmpty ? fmtAuditQty(q) : '${fmtAuditQty(q)} $unit';
}

/// Barang tidak wajar beserta alasannya (Tahap 5). Opname tidak bisa disetujui
/// selama ada yang belum beralasan, jadi kartu ini tampil di atas hasil hitung.
/// [onSave] null = hanya baca.
class AuditReasonsCard extends StatefulWidget {
  final List<StockAuditItem> items;
  final Future<void> Function(Map<StockAuditItem, String> changes)? onSave;

  const AuditReasonsCard({super.key, required this.items, this.onSave});

  @override
  State<AuditReasonsCard> createState() => _AuditReasonsCardState();
}

class _AuditReasonsCardState extends State<AuditReasonsCard> {
  final Map<int, TextEditingController> _controllers = {};
  bool _saving = false;

  // Isian per baris. Sesudah tersimpan, alasan di server sama dengan yang
  // diketik, jadi tidak perlu disinkronkan ulang.
  TextEditingController _controller(StockAuditItem it) =>
      _controllers.putIfAbsent(it.id ?? it.hashCode, () => TextEditingController(text: it.reason));

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<StockAuditItem, String> get _changes => {
        for (final it in widget.items)
          if (_controller(it).text.trim() != it.reason.trim()) it: _controller(it).text.trim(),
      };

  int get _missing => widget.items.where((it) => _controller(it).text.trim().isEmpty).length;

  Future<void> _save() async {
    final changes = _changes;
    if (changes.isEmpty || widget.onSave == null) return;
    setState(() => _saving = true);
    try {
      await widget.onSave!(changes);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final editable = widget.onSave != null;
    final missing = _missing;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.items.length} barang tidak wajar'
                  '${missing > 0 ? ' · $missing belum diberi alasan' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Selisihnya melewati batas wajar. Tulis alasannya; opname baru bisa disetujui sesudah semua barang beralasan.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          for (final it in widget.items) ...[
            const SizedBox(height: 12),
            Text(
              '${it.displayName}: ${it.shortage < 0 ? 'lebih' : 'kurang'} ${fmtAuditQtyUnit(it.shortage.abs(), it.unit)}, '
              'batas ${fmtAuditQtyUnit(it.maxShortage, it.unit)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            if (editable)
              TextField(
                controller: _controller(it),
                maxLength: 255,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Alasan, mis. tumpah saat closing',
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              )
            else
              Text(
                it.reason.isEmpty ? 'Belum ada alasan' : 'Alasan: ${it.reason}',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: it.reason.isEmpty ? FontStyle.italic : FontStyle.normal,
                  color: it.reason.isEmpty ? AppTheme.danger : AppTheme.textSecondary,
                ),
              ),
          ],
          if (editable) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _saving || _changes.isEmpty ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Menyimpan…' : 'Simpan alasan'),
            ),
          ],
        ],
      ),
    );
  }
}
