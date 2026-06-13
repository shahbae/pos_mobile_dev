import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/product_model.dart';
import '../../../utils/currency.dart';

class ProductDetailPage extends ConsumerWidget {
  final Product product;
  const ProductDetailPage({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,

      appBar: AppBar(
        title: const Text("Detail Produk"),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            // =====================
            // HEADER NAME
            // =====================
            Text(
              product.name,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 6),

            Text(
              product.sku != null && product.sku!.isNotEmpty
                  ? "SKU: ${product.sku}"
                  : "Informasi produk",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 18),

            // =====================
            // DETAIL CARD
            // =====================
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _row("SKU", product.sku ?? "-"),
                    _row("Kategori", product.categoryName ?? "-"),
                    _row("Harga Beli",
                        formatRupiah(product.purchasePriceNum)),
                    _row("Harga Jual",
                        formatRupiah(product.sellingPriceNum)),
                    _row("Profit",
                        formatRupiah(product.profitMarginNum)),
                    _row("Slot Topping Gratis",
                        product.freeToppingSlots > 0
                            ? "${product.freeToppingSlots} topping"
                            : "Tidak ada"),
                    _row("Dibuat", _formatDate(product.createdAt)),
                  ],
                ),
              ),
            ),

                  ],
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}
