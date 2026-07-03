import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/data/models/product_model.dart';
import 'package:pos_mobile/data/models/product_variant_model.dart';
import 'package:pos_mobile/presentation/providers/product_pagination_provider.dart';
import 'package:pos_mobile/presentation/providers/product_provider.dart';
import 'package:pos_mobile/presentation/providers/product_transaction_provider.dart';
import 'package:pos_mobile/presentation/pages/product_transactions/checkout_page.dart';
import 'package:pos_mobile/presentation/widgets/topping_picker_sheet.dart';
import 'package:pos_mobile/presentation/widgets/variant_picker_sheet.dart';
import 'package:pos_mobile/utils/currency.dart';

class ProductTransactionPage extends ConsumerWidget {
  const ProductTransactionPage({super.key});

  /// Alur tap produk: cek variant → (pilih variant) → (pilih topping) → masuk cart.
  Future<void> _onProductTap(BuildContext context, WidgetRef ref, Product product) async {
    final notifier = ref.read(productTransactionProvider.notifier);

    // Produk yang bahannya habis (product_ready == false) tak bisa dijual.
    // productReady == null (view lintas cabang) tetap diizinkan.
    if (!product.ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produk ini stoknya habis'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 1. Variant: pakai yang sudah embedded dari list produk; fallback fetch
    //    hanya bila ditandai punya variant tapi datanya belum ada.
    List<ProductVariant> variants = product.variants;
    if (product.hasVariants && variants.isEmpty) {
      try {
        variants = await ref.read(productVariantsProvider(product.id).future);
      } catch (_) {
        variants = const [];
      }
      if (!context.mounted) return;
    }

    // 2. Bila produk punya variant aktif, kasir wajib memilih salah satu.
    ProductVariant? variant;
    if (variants.isNotEmpty) {
      variant = await showVariantPicker(context, product: product, variants: variants);
      if (variant == null) return; // dibatalkan
      if (!context.mounted) return;
    }

    // 3. Topping. Slot gratis diambil dari variant bila dipilih, kalau tidak
    //    dari produk. Buka picker bila salah satunya mengizinkan topping gratis.
    final hasFreeToppings =
        variant != null ? variant.hasFreeToppings : product.hasFreeToppings;
    if (hasFreeToppings) {
      final result = await showToppingPicker(context, product: product, variant: variant);
      if (result == null) return;
      notifier.addLineWithToppings(
        product,
        variant: variant,
        quantity: result.quantity,
        freeToppings: result.freeToppings,
        extraToppings: result.extraToppings,
      );
    } else {
      notifier.addToCart(product, variant: variant);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productState = ref.watch(productPaginationProvider);
    final cartState = ref.watch(productTransactionProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text("Pilih Produk"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: TextField(
              onChanged: (value) => ref.read(productPaginationProvider.notifier).search(value),
              decoration: InputDecoration(
                hintText: "Cari produk...",
                prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.bgLight,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.brandBlue, width: 1.5),
                ),
              ),
            ),
          ),
          // Tab kategori (client-side). "Semua" + tiap kategori dari katalog.
          if (productState.categories.isNotEmpty)
            _CategoryTabs(
              categories: productState.categories,
              selectedId: productState.categoryId,
              onSelect: (id) =>
                  ref.read(productPaginationProvider.notifier).selectCategory(id),
            ),
          Expanded(
            child: productState.loading && productState.allItems.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : productState.items.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            "Produk tidak ditemukan",
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      )
                    : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: productState.items.length,
                    itemBuilder: (context, index) {
                      final product = productState.items[index];
                      // false = habis (dim + non-aktif). null = view lintas
                      // cabang (jangan tampilkan indikator). true = tersedia.
                      final soldOut = product.productReady == false;
                      return Opacity(
                        opacity: soldOut ? 0.5 : 1,
                        child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.borderLight),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _onProductTap(context, ref, product),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: _ProductThumb(imageUrl: product.imageUrl),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  product.hasVariants
                                      ? "mulai ${formatRupiah(product.minVariantPriceNum)}"
                                      : formatRupiah(product.sellingPriceNum),
                                  style: const TextStyle(
                                    color: AppTheme.brandBlue,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Indikator ketersediaan; disembunyikan bila
                                    // productReady == null (view lintas cabang).
                                    if (product.productReady != null)
                                      Text(
                                        soldOut ? "Habis" : "Tersedia",
                                        style: TextStyle(
                                          color: soldOut ? AppTheme.danger : Colors.green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    else
                                      const SizedBox.shrink(),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: soldOut ? AppTheme.textSecondary : AppTheme.brandBlue,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.add, color: Colors.white, size: 16),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: cartState.items.isEmpty
          ? null
          : SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.brandBlue.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${cartState.items.length} Item dipilih",
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                        Text(
                          formatRupiah(cartState.total),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CheckoutPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brandBlue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Checkout",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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

/// Baris tab kategori yang bisa di-scroll horizontal. "Semua" (id null) selalu
/// paling depan, diikuti tiap kategori dari katalog.
class _CategoryTabs extends StatelessWidget {
  final List<ProductCategoryTab> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelect;

  const _CategoryTabs({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _chip('Semua', selectedId == null, () => onSelect(null)),
            for (final c in categories) ...[
              const SizedBox(width: 8),
              _chip(c.name, selectedId == c.id, () => onSelect(c.id)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.brandBlue : AppTheme.bgLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.brandBlue : AppTheme.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// Gambar produk dengan fallback ikon (saat tidak ada URL / gagal dimuat).
class _ProductThumb extends StatelessWidget {
  final String? imageUrl;
  const _ProductThumb({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppTheme.bgLight,
      child: const Center(
        child: Icon(Icons.inventory_2_outlined, color: AppTheme.brandBlue, size: 40),
      ),
    );

    if (imageUrl == null) return placeholder;

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: AppTheme.bgLight,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }
}
