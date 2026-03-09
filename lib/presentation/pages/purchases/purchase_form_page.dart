import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/purchase_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../providers/product_provider.dart';

class PurchaseFormPage extends ConsumerStatefulWidget {
  const PurchaseFormPage({super.key});

  @override
  ConsumerState<PurchaseFormPage> createState() => _PurchaseFormPageState();
}

class _PurchaseItem {
  int? productId;
  int quantity = 1;
  TextEditingController qtyController = TextEditingController(text: '1');
  TextEditingController costController = TextEditingController();

  _PurchaseItem() {
    qtyController.addListener(() {
      final parsed = int.tryParse(qtyController.text);
      if (parsed != null && parsed >= 1) quantity = parsed;
    });
  }

  void dispose() {
    qtyController.dispose();
    costController.dispose();
  }
}

class _PurchaseFormPageState extends ConsumerState<PurchaseFormPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  int? _selectedSupplierId;
  final TextEditingController _noteController = TextEditingController();
  final List<_PurchaseItem> _items = [_PurchaseItem()];
  final _formatter = NumberFormat('#,###', 'id_ID');

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

  // ─── SUBMIT ───────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal harus ada 1 produk')),
      );
      return;
    }

    // Validate that all items have a selected product and valid price
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].productId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Produk baris ke-${i + 1} belum dipilih')),
        );
        return;
      }
    }

    setState(() => _loading = true);

    final repo = ref.read(purchaseRepositoryProvider);

    final List<Map<String, dynamic>> itemsPayload = _items.map((it) {
      final reqDigits = it.costController.text.replaceAll(RegExp(r'[^0-9]'), '');
      return {
        'product_id': it.productId,
        'quantity': it.quantity,
        'unit_cost': '$reqDigits.00',
      };
    }).toList();

    final payload = {
      'supplier_id': _selectedSupplierId,
      'items': itemsPayload,
      'note': _noteController.text.trim(),
    };

    debugPrint('[PurchaseForm] payload=$payload');

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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error submit: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Terjadi kesalahan saat menyimpan'),
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

  // ─── BUILD ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    // Watch providers for dropdowns
    final suppliersAsync = ref.watch(supplierListProvider(null));
    final productsAsync = ref.watch(productListProvider(null));

    // Calculate Grand Total for UI
    int totalEstimated = 0;
    for (var it in _items) {
      final cst = int.tryParse(it.costController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      totalEstimated += (it.quantity * cst);
    }

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
                          // Pastikan valid
                          if (_selectedSupplierId != null &&
                              !suppliers.any((s) => s.id == _selectedSupplierId)) {
                            _selectedSupplierId = null;
                          }

                          return DropdownButtonFormField<int>(
                            value: _selectedSupplierId,
                            validator: (v) => v == null ? 'Pemasok wajib dipilih' : null,
                            decoration: InputDecoration(
                              hintText: 'Pilih pemasok',
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
                            ),
                            items: suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                            onChanged: (v) => setState(() => _selectedSupplierId = v),
                          );
                        },
                        loading: () => const CircularProgressIndicator(),
                        error: (_, __) => const Text('Gagal memuat pemasok', style: TextStyle(color: Colors.red)),
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
                        decoration: InputDecoration(
                          hintText: 'Contoh: pembelian stok awal',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cs.primary, width: 1.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Produk Selection (Items) ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Daftar Produk',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _items.add(_PurchaseItem());
                        });
                      },
                      icon: Icon(Icons.add_shopping_cart, color: cs.primary, size: 18),
                      label: Text('Tambah Baris', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
                    )
                  ],
                ),
                const SizedBox(height: 12),

                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    final item = _items[i];
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
                              Text('Produk #${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              if (_items.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _items[i].dispose();
                                      _items.removeAt(i);
                                    });
                                  },
                                  tooltip: 'Hapus baris',
                                )
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          // Dropdown Product
                          productsAsync.when(
                            data: (products) {
                              if (item.productId != null && !products.any((p) => p.id == item.productId)) {
                                item.productId = null;
                              }
                              return DropdownButtonFormField<int>(
                                value: item.productId,
                                validator: (v) => v == null ? 'Produk wajib dipilih' : null,
                                decoration: InputDecoration(
                                  hintText: 'Pilih produk...',
                                  filled: true,
                                  fillColor: const Color(0xFFF9FAFB),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                                ),
                                items: products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                                onChanged: (v) {
                                  setState(() {
                                    item.productId = v;
                                    // Bawa harga belinya sbg default (jika ada)
                                    final prObj = products.firstWhere((element) => element.id == v);
                                    final purchasePrice = prObj.purchasePriceNum.toInt();
                                    if(purchasePrice > 0){
                                      item.costController.text = _formatter.format(purchasePrice);
                                    }
                                  });
                                },
                              );
                            },
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (_, __) => const Text('Gagal meload produk'),
                          ),

                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Kuantitas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: item.qtyController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFFF9FAFB),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                                      ),
                                      onChanged: (v) => setState((){}),
                                    )
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Harga Beli Satuan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: item.costController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        prefixText: 'Rp ',
                                        filled: true,
                                        fillColor: const Color(0xFFF9FAFB),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                                      ),
                                      onChanged: (value) {
                                        final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
                                        final num = int.tryParse(digits) ?? 0;
                                        if (num == 0) return;
                                        item.costController.value = TextEditingValue(
                                          text: _formatter.format(num),
                                          selection: TextSelection.collapsed(offset: _formatter.format(num).length),
                                        );
                                        setState((){});
                                      },
                                    )
                                  ],
                                ),
                              ),
                            ],
                          )

                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // ── Summary Totals ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.primary.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Estimasi:',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                      ),
                      Text(
                        'Rp ${_formatter.format(totalEstimated)}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.primary),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Submit button ──
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
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Simpan Pembelian',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                              ),
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
}
