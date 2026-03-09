import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/product_provider.dart';
import '../../providers/stock_movement_provider.dart';

class StockMovementFormPage extends ConsumerStatefulWidget {
  const StockMovementFormPage({super.key});

  @override
  ConsumerState<StockMovementFormPage> createState() =>
      _StockMovementFormPageState();
}

class _StockMovementFormPageState extends ConsumerState<StockMovementFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  int? _selectedProductId;
  String _selectedReferenceType = 'manual';
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  final List<String> _referenceTypes = ['manual', 'purchase', 'sales'];

  @override
  void dispose() {
    _qtyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih produk terlebih dahulu')),
      );
      return;
    }

    setState(() => _loading = true);

    final repo = ref.read(stockMovementRepositoryProvider);

    final payload = {
      'product_id': _selectedProductId,
      'new_qty': int.tryParse(_qtyController.text) ?? 1,
      'reference_type': _selectedReferenceType,
    };

    try {
      await repo.adjustStock(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Mutasi stok berhasil disimpan'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Gagal menyimpan mutasi stok'),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final productsAsync = ref.watch(productListProvider(null));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Catat Mutasi Stok Manual'),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── PRODUK ──
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
                    const Text('Pilih Produk *',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                    const SizedBox(height: 8),
                    productsAsync.when(
                      data: (products) {
                        return DropdownButtonFormField<int>(
                          value: _selectedProductId,
                          validator: (v) =>
                              v == null ? 'Produk wajib dipilih' : null,
                          decoration: InputDecoration(
                            hintText: 'Pilih produk...',
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: cs.primary, width: 1.6)),
                          ),
                          items: products
                              .map((p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(p.name)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedProductId = v),
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const Text('Gagal memuat produk'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── DETAIL MUTASI ──
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
                    const Text('Tipe Referensi *',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedReferenceType,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: cs.primary, width: 1.6)),
                      ),
                      items: _referenceTypes.map((t) {
                        String label = t;
                        if (t == 'manual') label = 'Manual (Penyesuaian)';
                        if (t == 'purchase') label = 'Purchase (Pembelian)';
                        if (t == 'sales') label = 'Sales (Penjualan)';
                        return DropdownMenuItem(value: t, child: Text(label));
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedReferenceType = v!),
                    ),
                    const SizedBox(height: 20),
                    const Text('Stok Aktual (Terbaru) *',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Stok aktual wajib diisi';
                        final num = int.tryParse(v);
                        if (num == null || num < 0) return 'Stok aktual tidak valid';
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'Contoh: 3280',
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: cs.primary, width: 1.6)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Catatan Tambahan',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Contoh: opname bulanan',
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: cs.primary, width: 1.6)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── SUBMIT ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: cs.primary.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('Simpan Mutasi',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 15)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
