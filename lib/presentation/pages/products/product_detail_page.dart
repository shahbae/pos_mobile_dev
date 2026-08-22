import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/product_model.dart';
import '../../providers/product_provider.dart';
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
            // IMAGE
            // =====================
            if (product.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    product.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade100,
                      child: Icon(Icons.inventory_2_outlined,
                          color: theme.colorScheme.primary, size: 48),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

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
                    // Dipakai BE untuk menghitung estimasi siap di nota.
                    // Pengisiannya lewat web admin, di sini hanya info.
                    _row("Waktu Pembuatan",
                        product.prepMinutes > 0
                            ? "${product.prepMinutes} menit"
                            : "Belum diatur"),
                    _row("Dibuat", _formatDate(product.createdAt)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // =====================
            // VARIASI / UKURAN
            // =====================
            _VariantsSection(
              productId: product.id,
              productPrepMinutes: product.prepMinutes,
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
      final dt = DateTime.parse(dateStr).toLocal();
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

/// Bagian daftar variasi/ukuran produk (read-only) di halaman detail.
class _VariantsSection extends ConsumerWidget {
  final int productId;

  /// Nilai produk induk — dipakai bila varian tidak punya override.
  final int productPrepMinutes;

  const _VariantsSection({
    required this.productId,
    required this.productPrepMinutes,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final variantsAsync = ref.watch(productVariantsProvider(productId));

    return variantsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text(
        'Gagal memuat variasi: $e',
        style: TextStyle(color: Colors.red.shade400, fontSize: 13),
      ),
      data: (variants) {
        if (variants.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Variasi / Ukuran",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "(${variants.length})",
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < variants.length; i++) ...[
                    if (i > 0) Divider(color: Colors.grey.shade200, height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.local_offer_outlined,
                              size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  variants[i].name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                                if (variants[i]
                                        .effectivePrepFor(productPrepMinutes) >
                                    0)
                                  Text(
                                    '${variants[i].effectivePrepFor(productPrepMinutes)} menit',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            formatRupiah(variants[i].sellingPriceNum),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
