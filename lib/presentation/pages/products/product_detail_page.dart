import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/product_model.dart';
import '../../providers/product_provider.dart';
import 'product_form_page.dart';
import '../../../utils/currency.dart';

class ProductDetailPage extends ConsumerWidget {
  final Product product;
  const ProductDetailPage({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(productRepositoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text("Detail Produk"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              await repo.deleteProduct(product.id);
              ref.invalidate(productListProvider);
              Navigator.pop(context);
            },
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.name,
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),

            const SizedBox(height: 10),

            info("SKU", product.sku ?? ''),
            info("Stok", "${product.stock}"),
            info("Harga Beli", formatRupiah(product.purchasePrice)),
            info("Harga Jual", formatRupiah(product.sellingPrice)),
            info("Profit", formatRupiah(product.profitMargin)),

            const Spacer(),

            SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductFormPage(product: product),
                    ),
                  );

                  if (updated == true) {
                    ref.invalidate(productListProvider);
                    Navigator.pop(context);
                  }
                },
                child: const Text("Edit Product"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
