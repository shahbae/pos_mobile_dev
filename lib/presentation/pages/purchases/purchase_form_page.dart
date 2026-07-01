import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/purchase_template_model.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../providers/material_provider.dart';
import '../../providers/topping_provider.dart';

class PurchaseFormPage extends ConsumerStatefulWidget {
  const PurchaseFormPage({super.key});

  @override
  ConsumerState<PurchaseFormPage> createState() => _PurchaseFormPageState();
}

/// Opsi template pada dropdown — gabungan template milik material & topping.
/// `template_id` diasumsikan unik global (1 tabel purchase_templates di BE).
class _TemplateOption {
  final int templateId;
  final String ownerName; // nama material/topping
  final String ownerType; // 'Material' | 'Topping'
  final String unit; // base unit (gram/ml/pcs)
  final PurchaseTemplate template;

  _TemplateOption({
    required this.templateId,
    required this.ownerName,
    required this.ownerType,
    required this.unit,
    required this.template,
  });

  /// Label dropdown: "Teh · Lusin (1200 gram)".
  String get label {
    final bq = template.baseQtyNum;
    final bqStr = bq == bq.truncate() ? bq.truncate().toString() : bq.toString();
    return '$ownerName · ${template.name} ($bqStr${unit.isNotEmpty ? ' $unit' : ''})';
  }
}

class _PurchaseItem {
  int? templateId;
  int qty = 1;
  final TextEditingController qtyController = TextEditingController(text: '1');

  _PurchaseItem() {
    qtyController.addListener(() {
      final parsed = int.tryParse(qtyController.text);
      if (parsed != null && parsed >= 1) qty = parsed;
    });
  }

  void dispose() {
    qtyController.dispose();
  }
}

class _PurchaseFormPageState extends ConsumerState<PurchaseFormPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  int? _selectedSupplierId;
  final TextEditingController _noteController = TextEditingController();
  final List<_PurchaseItem> _items = [_PurchaseItem()];

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _noteController.dispose();
    for (var item in _items) {
      item.dispose();
    }
    _animCtrl.dispose();
    super.dispose();
  }

  /// Bangun daftar opsi template dari semua material & topping.
  Map<int, _TemplateOption> _buildTemplateOptions() {
    final materials = ref.read(materialListProvider).valueOrNull ?? [];
    final toppings = ref.read(toppingListProvider).valueOrNull ?? [];
    final map = <int, _TemplateOption>{};

    for (final m in materials) {
      for (final t in m.purchaseTemplates) {
        map[t.id] = _TemplateOption(
          templateId: t.id,
          ownerName: m.name,
          ownerType: 'Material',
          unit: m.unit,
          template: t,
        );
      }
    }
    for (final tp in toppings) {
      for (final t in tp.purchaseTemplates) {
        map[t.id] = _TemplateOption(
          templateId: t.id,
          ownerName: tp.name,
          ownerType: 'Topping',
          unit: tp.unit,
          template: t,
        );
      }
    }
    return map;
  }

  // ─── SUBMIT ───────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    for (int i = 0; i < _items.length; i++) {
      if (_items[i].templateId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item baris ke-${i + 1} belum dipilih')),
        );
        return;
      }
    }

    setState(() => _loading = true);

    final repo = ref.read(purchaseRepositoryProvider);

    // Revisi BE 2026-06-29: items berisi {template_id, qty} saja.
    final itemsPayload = _items
        .map((it) => {'template_id': it.templateId, 'qty': it.qty})
        .toList();

    final note = _noteController.text.trim();
    final payload = {
      'supplier_id': _selectedSupplierId,
      'items': itemsPayload,
      if (note.isNotEmpty) 'note': note,
    };

    try {
      await repo.createPurchase(payload);
      ref.invalidate(purchaseListProvider);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Data pembelian berhasil disimpan'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('Gagal menyimpan: $e')),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── BUILD ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final suppliersAsync = ref.watch(supplierListProvider(null));
    final materialsAsync = ref.watch(materialListProvider);
    final toppingsAsync = ref.watch(toppingListProvider);

    final options = _buildTemplateOptions();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Catat Pembelian Stok',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeIn,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Supplier Selection ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Informasi Pemasok',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Pilih Pemasok *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      suppliersAsync.when(
                        data: (suppliers) {
                          if (_selectedSupplierId != null &&
                              !suppliers.any((s) => s.id == _selectedSupplierId)) {
                            _selectedSupplierId = null;
                          }
                          return DropdownButtonFormField<int>(
                            value: _selectedSupplierId,
                            validator: (v) => v == null ? 'Pemasok wajib dipilih' : null,
                            decoration: _fieldDeco(cs, hint: 'Pilih pemasok'),
                            items: suppliers
                                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedSupplierId = v),
                          );
                        },
                        loading: () => const CircularProgressIndicator(),
                        error: (_, __) => const Text('Gagal memuat pemasok',
                            style: TextStyle(color: Colors.red)),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Catatan (Opsional)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _noteController,
                        maxLines: 2,
                        decoration: _fieldDeco(cs, hint: 'Contoh: restok mingguan'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Items ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Daftar Item',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _items.add(_PurchaseItem())),
                      icon: Icon(Icons.add_shopping_cart, color: cs.primary, size: 18),
                      label: Text('Tambah Baris',
                          style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
                    )
                  ],
                ),
                const SizedBox(height: 12),

                if (materialsAsync.isLoading || toppingsAsync.isLoading)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ))
                else if (options.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: const Text(
                      'Belum ada template pembelian. Atur template pada master '
                      'material/topping terlebih dahulu (lewat admin web).',
                      style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                    ),
                  )
                else
                  ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, i) => _itemCard(cs, i, options),
                  ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_loading || options.isEmpty) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: cs.primary.withOpacity(0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 20),
                              SizedBox(width: 8),
                              Text('Simpan Pembelian',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _itemCard(ColorScheme cs, int i, Map<int, _TemplateOption> options) {
    final item = _items[i];
    final opt = item.templateId != null ? options[item.templateId] : null;

    if (item.templateId != null && !options.containsKey(item.templateId)) {
      item.templateId = null;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Item #${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
              if (_items.length > 1)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                  tooltip: 'Hapus baris',
                  onPressed: () => setState(() {
                    _items[i].dispose();
                    _items.removeAt(i);
                  }),
                )
            ],
          ),
          const SizedBox(height: 8),

          // Dropdown template
          DropdownButtonFormField<int>(
            value: item.templateId,
            isExpanded: true,
            validator: (v) => v == null ? 'Template wajib dipilih' : null,
            decoration: _fieldDeco(cs, hint: 'Pilih template pembelian...'),
            items: options.values
                .map((o) => DropdownMenuItem(
                      value: o.templateId,
                      child: Text(o.label, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => setState(() => item.templateId = v),
          ),

          if (opt != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(opt.ownerType,
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
            ),
          ],

          const SizedBox(height: 16),

          // Qty stepper
          Row(
            children: [
              const Text('Jumlah Template',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              _stepBtn(Icons.remove, () {
                if (item.qty > 1) {
                  setState(() {
                    item.qty--;
                    item.qtyController.text = item.qty.toString();
                  });
                }
              }),
              SizedBox(
                width: 64,
                child: TextFormField(
                  controller: item.qtyController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              _stepBtn(Icons.add, () {
                setState(() {
                  item.qty++;
                  item.qtyController.text = item.qty.toString();
                });
              }),
            ],
          ),

          if (opt != null) ...[
            const SizedBox(height: 10),
            Text(
              '= ${_baseQtyTotal(opt, item.qty)}'
              '${opt.unit.isNotEmpty ? ' ${opt.unit}' : ''}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }

  String _baseQtyTotal(_TemplateOption opt, int qty) {
    final total = opt.template.baseQtyNum * qty;
    return total == total.truncate() ? total.truncate().toString() : total.toString();
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF374151)),
      ),
    );
  }

  InputDecoration _fieldDeco(ColorScheme cs, {required String hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.6),
      ),
    );
  }
}
