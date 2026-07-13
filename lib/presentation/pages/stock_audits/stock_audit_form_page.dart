import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/stock_audit_model.dart';
import 'package:pos_mobile/data/models/stock_pack_model.dart';
import 'package:pos_mobile/presentation/providers/material_provider.dart';
import 'package:pos_mobile/presentation/providers/topping_provider.dart';
import 'package:pos_mobile/presentation/providers/plastic_provider.dart';
import 'package:pos_mobile/presentation/providers/sedotan_provider.dart';
import 'package:pos_mobile/presentation/providers/stock_audit_provider.dart';
import 'package:pos_mobile/presentation/providers/stock_level_provider.dart';
import 'package:pos_mobile/presentation/widgets/stock_packs_view.dart';
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
  // key "m:<id>" / "t:<id>" / "p:<id>" / "s:<id>" -> qty (string).
  // Bahan integer; topping, plastik & sedotan desimal.
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
        final key = it.materialId != null
            ? 'm:${it.materialId}'
            : (it.toppingId != null
                ? 't:${it.toppingId}'
                : (it.plasticId != null
                    ? 'p:${it.plasticId}'
                    : (it.sedotanId != null ? 's:${it.sedotanId}' : null)));
        if (key == null) continue;
        _physical[key] = _fmtNum(it.physicalQty);
        if (it.returnedQty > 0) {
          _returned[key] = _fmtNum(it.returnedQty);
          _returnedOpen.add(key);
        }
      }
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  /// Tampilkan bilangan bulat tanpa desimal, selain itu apa adanya.
  String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _submit() async {
    final items = <Map<String, dynamic>>[];
    _physical.forEach((key, val) {
      final v = val.trim();
      if (v.isEmpty) return;
      final id = int.tryParse(key.substring(2));
      if (id == null) return;
      final ret = _returned[key]?.trim() ?? '';
      items.add({
        if (key.startsWith('m:')) 'material_id': id,
        if (key.startsWith('t:')) 'topping_id': id,
        if (key.startsWith('p:')) 'plastic_id': id,
        if (key.startsWith('s:')) 'sedotan_id': id,
        'physical_qty': v, // string desimal sesuai BE
        if (ret.isNotEmpty) 'returned_qty': ret,
      });
    });

    if (items.isEmpty) {
      _toast('Isi jumlah fisik minimal 1 item', Colors.orange);
      return;
    }

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
    } catch (e) {
      if (mounted) _toast('$e', AppTheme.danger);
    } finally {
      if (mounted) setState(() => _saving = false);
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
    final materialsAsync = ref.watch(materialListProvider);
    final toppingsAsync = ref.watch(toppingListProvider);
    final plasticsAsync = ref.watch(plasticListProvider);
    final sedotansAsync = ref.watch(sedotanListProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Audit' : 'Audit Baru'),
        centerTitle: true,
      ),
      body: Builder(builder: (_) {
        if (materialsAsync.isLoading || toppingsAsync.isLoading || plasticsAsync.isLoading || sedotansAsync.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (materialsAsync.hasError && toppingsAsync.hasError && plasticsAsync.hasError && sedotansAsync.hasError) {
          return const Center(child: Text('Gagal memuat material, topping, plastik & sedotan'));
        }
        final materials = materialsAsync.valueOrNull ?? [];
        final toppings = toppingsAsync.valueOrNull ?? [];
        final plastics = plasticsAsync.valueOrNull ?? [];
        final sedotans = sedotansAsync.valueOrNull ?? [];

        // Info stok (opsional): stok sistem + masuk hari ini per item. Tidak
        // memblok tampilan — muncul begitu data stok tersedia.
        final levels = ref.watch(materialStockLevelsProvider).valueOrNull ?? const [];
        final toppingStocks = ref.watch(toppingStockListProvider).valueOrNull ?? const [];
        final plasticStocks = ref.watch(plasticStockListProvider).valueOrNull ?? const [];
        final sedotanStocks = ref.watch(sedotanStockListProvider).valueOrNull ?? const [];
        final levelByMat = {
          for (final l in levels)
            if (l.materialId != null) l.materialId!: l,
        };
        final stockByTop = {for (final s in toppingStocks) s.toppingId: s};
        final stockByPlastic = {for (final s in plasticStocks) s.plasticId: s};
        final stockBySedotan = {for (final s in sedotanStocks) s.sedotanId: s};

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
                  if (materials.isNotEmpty) ...[
                    _sectionLabel('MATERIAL'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: _box(),
                      child: Column(
                        children: [
                          for (int i = 0; i < materials.length; i++) ...[
                            if (i > 0) const Divider(height: 1, color: AppTheme.borderLight),
                            _qtyRow('m:${materials[i].id}', materials[i].name,
                                materials[i].unit, true,
                                systemQty: levelByMat[materials[i].id]?.qtyOnHand,
                                incomingToday: levelByMat[materials[i].id]?.incomingToday,
                                packs: levelByMat[materials[i].id]?.packs),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (toppings.isNotEmpty) ...[
                    _sectionLabel('TOPPING'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: _box(),
                      child: Column(
                        children: [
                          for (int i = 0; i < toppings.length; i++) ...[
                            if (i > 0) const Divider(height: 1, color: AppTheme.borderLight),
                            _qtyRow('t:${toppings[i].id}', toppings[i].name,
                                toppings[i].unit, false,
                                systemQty: stockByTop[toppings[i].id]?.qty,
                                incomingToday: stockByTop[toppings[i].id]?.incomingToday,
                                packs: stockByTop[toppings[i].id]?.packs),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (plastics.isNotEmpty) ...[
                    _sectionLabel('PLASTIK'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: _box(),
                      child: Column(
                        children: [
                          for (int i = 0; i < plastics.length; i++) ...[
                            if (i > 0) const Divider(height: 1, color: AppTheme.borderLight),
                            _qtyRow('p:${plastics[i].id}', plastics[i].name,
                                plastics[i].unit, false,
                                systemQty: stockByPlastic[plastics[i].id]?.qty,
                                incomingToday: stockByPlastic[plastics[i].id]?.incomingToday,
                                packs: stockByPlastic[plastics[i].id]?.packs),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (sedotans.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionLabel('SEDOTAN'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: _box(),
                      child: Column(
                        children: [
                          for (int i = 0; i < sedotans.length; i++) ...[
                            if (i > 0) const Divider(height: 1, color: AppTheme.borderLight),
                            _qtyRow('s:${sedotans[i].id}', sedotans[i].name,
                                sedotans[i].unit, false,
                                systemQty: stockBySedotan[sedotans[i].id]?.qty,
                                incomingToday: stockBySedotan[sedotans[i].id]?.incomingToday,
                                packs: stockBySedotan[sedotans[i].id]?.packs),
                          ],
                        ],
                      ),
                    ),
                  ],
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
                    onPressed: _saving ? null : _submit,
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
      }),
    );
  }

  Widget _qtyRow(
    String key,
    String name,
    String unit,
    bool isMaterial, {
    num? systemQty,
    num? incomingToday,
    List<StockPack>? packs,
  }) {
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
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    if (unit.isNotEmpty)
                      Text(unit, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    if (systemQty != null) ...[
                      const SizedBox(height: 2),
                      Text('Sistem: ${_fmtNum(systemQty.toDouble())}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                    if (packs != null && packs.isNotEmpty)
                      StockPacksView(packs: packs, unit: unit),
                    if (incomingToday != null && incomingToday > 0)
                      Text('Masuk hari ini: ${_fmtNum(incomingToday.toDouble())}',
                          style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              SizedBox(
                  width: 120,
                  child: _numField(key, _physical, isMaterial, 'qty fisik', unit: unit)),
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
                      child: _numField(key, _returned, isMaterial, 'qty', unit: unit)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Field angka: semua item (material/topping/plastik) kini DESIMAL.
  /// [unit] ditampilkan sebagai suffix (mis. pcs / gram / ml) bila ada.
  Widget _numField(String key, Map<String, String> store, bool isMaterial, String hint,
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
