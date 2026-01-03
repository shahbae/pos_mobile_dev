import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/product_model.dart';
import '../../providers/product_provider.dart';
import '../../widgets/price_field.dart';

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
  late final buy = TextEditingController(
    text: widget.product?.purchasePrice.toString() ?? "",
  );
  late final sell = TextEditingController(
    text: widget.product?.sellingPrice.toString() ?? "",
  );

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

    final data = {
      "name": name.text,
      "sku": sku.text.isEmpty ? null : sku.text,
      "stock": int.tryParse(stock.text) ?? 0,
      "purchase_price": int.parse(buy.text.replaceAll(RegExp(r'[^0-9]'), '')),
      "selling_price": int.parse(sell.text.replaceAll(RegExp(r'[^0-9]'), '')),
    };

    final repo = ref.read(productRepositoryProvider);
    final editMode = widget.product != null;

    try {
      if (editMode) {
        await repo.updateProduct(widget.product!.id, data);
      } else {
        await repo.createProduct(data);
      }

      ref.invalidate(productListProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            editMode
                ? "Produk berhasil diperbarui"
                : "Produk berhasil ditambahkan",
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
    final editMode = widget.product != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(editMode ? "Edit Produk" : "Tambah Produk"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              field("Nama Produk", name),
              field("SKU (opsional)", sku, required: false),
              field("Stok", stock),
              PriceField(label: "Harga Beli", controller: buy),
              PriceField(label: "Harga Jual", controller: sell),

              const SizedBox(height: 20),

              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: loading ? null : submit,
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(editMode ? "Simpan" : "Buat Produk"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget field(String label, TextEditingController c, {bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        style: const TextStyle(color: Colors.white),
        validator: (v) =>
            required && (v == null || v.isEmpty) ? "Required" : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: const Color(0xFF1E293B),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF3B82F6)),
          ),
        ),
      ),
    );
  }
}
