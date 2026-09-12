import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/stock_audit_model.dart';
import 'package:pos_mobile/data/repositories/stock_audit_repository.dart';
import 'package:pos_mobile/presentation/providers/stock_audit_provider.dart';
import 'package:pos_mobile/presentation/widgets/confirm_dialog.dart';
import 'package:pos_mobile/theme/app_theme.dart';

class StockAuditFormPage extends ConsumerStatefulWidget {
  /// Bila diisi = mode edit draft (prefill + PUT). Null = buat audit baru.
  final StockAudit? audit;

  const StockAuditFormPage({super.key, this.audit});

  bool get isEdit => audit != null;

  @override
  ConsumerState<StockAuditFormPage> createState() => _StockAuditFormPageState();
}

class _StockAuditFormPageState extends ConsumerState<StockAuditFormPage> {
  final _notes = TextEditingController();
  // key AuditableItem.key ("material:7") -> qty (string desimal).
  final Map<String, String> _physical = {};
  final Map<String, String> _returned = {};
  // key yang field "Dikembalikan"-nya sedang ditampilkan.
  final Set<String> _returnedOpen = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final audit = widget.audit;
    if (audit != null) {
      _notes.text = audit.notes ?? '';
      for (final it in audit.items) {
        final key = _keyOfAuditItem(it);
        if (key == null) continue;
        _physical[key] = _fmtNum(it.physicalQty);
        if (it.returnedQty > 0) {
          _returned[key] = _fmtNum(it.returnedQty);
          _returnedOpen.add(key);
        }
      }
    }
  }

  /// Kunci draft lama supaya cocok dengan [AuditableItem.key]. Draft bisa
  /// berisi topping/plastik/sedotan dari sebelum opname dibatasi (BE §5).
  String? _keyOfAuditItem(StockAuditItem it) {
    if (it.materialId != null) return 'material:${it.materialId}';
    if (it.toppingId != null) return 'topping:${it.toppingId}';
    if (it.plasticId != null) return 'plastic:${it.plasticId}';
    if (it.sedotanId != null) return 'sedotan:${it.sedotanId}';
    return null;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  /// Tampilkan bilangan bulat tanpa desimal, selain itu apa adanya.
  String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _submit(List<AuditableItem> auditable) async {
    // Payload dibangun dari daftar auditable, bukan dari key yang diketik —
    // item yang sudah dilepas owner tidak ikut terkirim (kalau ikut, BE 422).
    final items = <Map<String, dynamic>>[];
    for (final it in auditable) {
      final v = _physical[it.key]?.trim() ?? '';
      if (v.isEmpty) continue;
      final ret = _returned[it.key]?.trim() ?? '';
      items.add({
        ...it.idPayload,
        'physical_qty': v, // string desimal sesuai BE
        if (ret.isNotEmpty) 'returned_qty': ret,
      });
    }

    if (items.isEmpty) {
      _toast('Isi jumlah fisik minimal 1 item', Colors.orange);
      return;
    }

    if (!mounted) return;
    final yakin = await confirmAction(
      context,
      title: widget.isEdit ? 'Simpan perubahan audit?' : 'Simpan draft audit?',
      message: '${items.length} item akan disimpan. Selisihnya baru memengaruhi stok setelah audit disetujui.',
      confirmLabel: 'Ya, simpan',
    );
    if (!yakin) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(stockAuditRepositoryProvider);
      if (widget.isEdit) {
        await repo.updateAudit(
          id: widget.audit!.id,
          notes: _notes.text.trim(),
          items: items,
        );
        ref.invalidate(stockAuditDetailProvider(widget.audit!.id));
      } else {
        await repo.createAudit(notes: _notes.text.trim(), items: items);
      }
      ref.invalidate(stockAuditListProvider);
      if (mounted) Navigator.pop(context, true);
    } on OpenDraftConflict catch (e) {
      // Cabang sudah punya draft terbuka (BE §2). Arahkan ke draft itu
      // daripada menampilkan error mentah.
      if (mounted) {
        setState(() => _saving = false);
        await _showOpenDraftDialog(e.message);
      }
      return;
    } catch (e) {
      if (mounted) _toast('$e', AppTheme.danger);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showOpenDraftDialog(String message) async {
    final goToList = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Masih ada draft opname'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tutup')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lihat Draft'),
          ),
        ],
      ),
    );
    if (goToList == true && mounted) {
      ref.invalidate(stockAuditListProvider);
      Navigator.pop(context, true); // kembali ke daftar audit
    }
  }

  void _toast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auditableAsync = ref.watch(auditableItemsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Audit' : 'Audit Baru'),
        centerTitle: true,
      ),
      body: auditableAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _errorView('$e'),
        data: (items) => items.isEmpty ? _emptyView() : _form(items),
      ),
    );
  }

  /// Daftar item opname ditentukan owner — kalau kosong, bukan error dan bukan
  /// spinner: kasih tahu apa yang kurang (BE §1).
  Widget _emptyView() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.rule_folder_outlined, size: 56, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Text('Belum ada item yang diatur untuk opname',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            SizedBox(height: 6),
            Text(
              'Owner atau supervisor perlu memilih dulu bahan mana yang '
              'dihitung saat opname.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );

  Widget _errorView(String msg) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(auditableItemsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      );

  /// Item draft lama yang sudah dilepas dari daftar opname (BE §5). Tidak bisa
  /// ikut dikirim (BE balas 422), jadi akan hilang saat draft disimpan —
  /// katakan itu di muka, jangan biarkan datanya lenyap diam-diam.
  List<StockAuditItem> _droppedItems(List<AuditableItem> auditable) {
    final audit = widget.audit;
    if (audit == null) return const [];
    final keys = auditable.map((e) => e.key).toSet();
    return audit.items
        .where((it) => !keys.contains(_keyOfAuditItem(it) ?? ''))
        .toList();
  }

  Widget _form(List<AuditableItem> items) {
    final dropped = _droppedItems(items);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                decoration: _box(),
                child: TextField(
                  controller: _notes,
                  minLines: 1,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Catatan (mis. Audit stok bulanan)',
                    prefixIcon: Icon(Icons.notes_outlined, color: AppTheme.brandBlue),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _sectionLabel('ITEM OPNAME'),
              const SizedBox(height: 8),
              Container(
                decoration: _box(),
                child: Column(
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: AppTheme.borderLight),
                      _qtyRow(items[i]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Hanya item yang dipilih owner yang dihitung saat opname.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
              if (dropped.isNotEmpty) _droppedNotice(dropped),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                // Guard dobel-simpan di FE; 409 dari BE cuma jaring terakhir.
                onPressed: _saving ? null : () => _submit(items),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.isEdit ? 'Simpan Perubahan' : 'Simpan Audit',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _droppedNotice(List<StockAuditItem> dropped) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text('Item ini tidak lagi masuk opname',
                      style: TextStyle(fontWeight: FontWeight.w800, color: Colors.orange)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${dropped.map((e) => e.displayName).join(', ')} — akan hilang '
                'dari draft ini begitu perubahan disimpan.',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );

  Widget _qtyRow(AuditableItem item) {
    final key = item.key;
    final open = _returnedOpen.contains(key);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    if (item.unit.isNotEmpty)
                      Text(item.unit,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text('Sistem: ${_fmtNum(item.systemQty)}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    if (item.incomingToday > 0)
                      Text('Masuk hari ini: ${_fmtNum(item.incomingToday)}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.green, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              SizedBox(
                  width: 120,
                  child: _numField(key, _physical, 'qty fisik', unit: item.unit)),
              IconButton(
                tooltip: open ? 'Batalkan dikembalikan' : 'Barang dikembalikan',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  open ? Icons.remove_circle_outline : Icons.assignment_return_outlined,
                  size: 20,
                  color: open ? AppTheme.danger : AppTheme.brandBlue,
                ),
                onPressed: () => setState(() {
                  if (open) {
                    _returnedOpen.remove(key);
                    _returned.remove(key);
                  } else {
                    _returnedOpen.add(key);
                  }
                }),
              ),
            ],
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.assignment_return_outlined, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  const Text('Dikembalikan',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const Spacer(),
                  SizedBox(
                      width: 120,
                      child: _numField(key, _returned, 'qty', unit: item.unit)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Field angka: semua item (material/topping/plastik/sedotan) DESIMAL.
  /// [unit] ditampilkan sebagai suffix (mis. pcs / gram / ml) bila ada.
  Widget _numField(String key, Map<String, String> store, String hint,
      {String unit = ''}) {
    return TextFormField(
      initialValue: store[key],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      textAlign: TextAlign.right,
      onChanged: (v) => store[key] = v,
      decoration: InputDecoration(
        hintText: hint,
        suffixText: unit.isEmpty ? null : unit,
        suffixStyle: const TextStyle(
            fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: AppTheme.bgLight,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.brandBlue),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textSecondary, letterSpacing: 1)),
      );

  BoxDecoration _box() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      );
}
