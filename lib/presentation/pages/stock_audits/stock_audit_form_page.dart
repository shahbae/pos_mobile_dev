import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/presentation/providers/material_provider.dart';
import 'package:pos_mobile/presentation/providers/topping_provider.dart';
import 'package:pos_mobile/presentation/providers/stock_audit_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

class StockAuditFormPage extends ConsumerStatefulWidget {
  const StockAuditFormPage({super.key});

  @override
  ConsumerState<StockAuditFormPage> createState() => _StockAuditFormPageState();
}

class _StockAuditFormPageState extends ConsumerState<StockAuditFormPage> {
  final _notes = TextEditingController();
  // key "m:<id>" / "t:<id>" -> qty fisik (string desimal)
  final Map<String, String> _physical = {};
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final items = <Map<String, dynamic>>[];
    _physical.forEach((key, val) {
      final v = val.trim();
      if (v.isEmpty) return;
      final id = int.tryParse(key.substring(2));
      if (id == null) return;
      items.add({
        if (key.startsWith('m:')) 'material_id': id,
        if (key.startsWith('t:')) 'topping_id': id,
        'physical_qty': v, // string desimal sesuai BE
      });
    });

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Isi jumlah fisik minimal 1 item'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(stockAuditRepositoryProvider).createAudit(
            notes: _notes.text.trim(),
            items: items,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final materialsAsync = ref.watch(materialListProvider);
    final toppingsAsync = ref.watch(toppingListProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Audit Baru'), centerTitle: true),
      body: Builder(builder: (_) {
        if (materialsAsync.isLoading || toppingsAsync.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (materialsAsync.hasError && toppingsAsync.hasError) {
          return const Center(child: Text('Gagal memuat material & topping'));
        }
        final materials = materialsAsync.valueOrNull ?? [];
        final toppings = toppingsAsync.valueOrNull ?? [];

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
                            _qtyRow('m:${materials[i].id}', materials[i].name, materials[i].unit),
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
                            _qtyRow('t:${toppings[i].id}', toppings[i].name, toppings[i].unit),
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
                        : const Text('Simpan Audit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _qtyRow(String key, String name, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (unit.isNotEmpty)
                  Text(unit, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              textAlign: TextAlign.right,
              onChanged: (v) => _physical[key] = v,
              decoration: InputDecoration(
                hintText: 'qty fisik',
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
            ),
          ),
        ],
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
