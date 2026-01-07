import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/product_model.dart';
import '../../providers/product_provider.dart';

class ProductFormPage extends ConsumerStatefulWidget {
  final Product? product;
  const ProductFormPage({super.key, this.product});

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool loading = false;

  late final name = TextEditingController(text: widget.product?.name ?? "");
  late final sku = TextEditingController(text: widget.product?.sku ?? "");
  late final stock = TextEditingController(
    text: widget.product?.stock.toString() ?? "",
  );
  late final buy = TextEditingController();
  late final sell = TextEditingController();

  final formatter = NumberFormat('#,###', 'id_ID');

  @override
  void initState() {
    super.initState();

    if (widget.product != null) {
      buy.text = formatter.format(widget.product!.purchasePrice);
      sell.text = formatter.format(widget.product!.sellingPrice);
    }
  }

  @override
  void dispose() {
    name.dispose();
    sku.dispose();
    stock.dispose();
    buy.dispose();
    sell.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    final payload = {
      "name": name.text,
      "sku": sku.text.isEmpty ? null : sku.text,
      "stock": int.tryParse(stock.text) ?? 0,
      "purchase_price": int.parse(buy.text.replaceAll(RegExp(r'[^0-9]'), '')),
      "selling_price": int.parse(sell.text.replaceAll(RegExp(r'[^0-9]'), '')),
    };

    final repo = ref.read(productRepositoryProvider);
    final edit = widget.product != null;

    try {
      if (edit) {
        await repo.updateProduct(widget.product!.id, payload);
      } else {
        await repo.createProduct(payload);
      }

      ref.invalidate(productListProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            edit ? "Produk berhasil diperbarui" : "Produk berhasil ditambahkan",
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text("Gagal menyimpan produk"),
        ),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final edit = widget.product != null;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,

      appBar: AppBar(
        title: Text(edit ? "Edit Produk" : "Tambah Produk"),
        elevation: 0,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _labeledField("Nama Produk", name),
              _labeledField("SKU (opsional)", sku, required: false),
              _labeledField("Stok", stock, inputType: TextInputType.number),

              _moneyField("Harga Beli", buy),
              _moneyField("Harga Jual", sell),

              const SizedBox(height: 22),

              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: loading ? null : submit,
                  child: loading
                      ? const CircularProgressIndicator()
                      : Text(edit ? "Simpan Perubahan" : "Buat Produk"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _labeledField(
    String label,
    TextEditingController c, {
    bool required = true,
    TextInputType inputType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: c,
            keyboardType: inputType,
            validator: (v) =>
                required && (v == null || v.isEmpty) ? "Wajib diisi" : null,
            decoration: InputDecoration(hintText: label),
          ),
        ],
      ),
    );
  }

  Widget _moneyField(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: c,
            keyboardType: TextInputType.number,
            validator: (v) => v == null || v.isEmpty ? "Wajib diisi" : null,
            decoration: const InputDecoration(prefixText: "Rp ", hintText: "0"),
            onChanged: (value) {
              final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
              c.value = TextEditingValue(
                text: formatter.format(int.tryParse(digits) ?? 0),
                selection: TextSelection.collapsed(
                  offset: formatter.format(int.tryParse(digits) ?? 0).length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
