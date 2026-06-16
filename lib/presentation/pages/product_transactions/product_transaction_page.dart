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

    // 1. Ambil variant aktif. Bila gagal, jangan blokir kasir → lanjut tanpa variant.
    List<ProductVariant> variants = const [];
    try {
      variants = await ref.read(productVariantsProvider(product.id).future);
    } catch (_) {
      variants = const [];
    }
    if (!context.mounted) return;

    // 2. Bila produk punya variant aktif, kasir wajib memilih salah satu.
    ProductVariant? variant;
    if (variants.isNotEmpty) {
      variant = await showVariantPicker(context, product: product, variants: variants);
      if (variant == null) return; // dibatalkan
      if (!context.mounted) return;
    }

    // 3. Topping (bila produk punya slot topping gratis), lalu masukkan ke cart.
    if (product.hasFreeToppings) {
      final result = await showToppingPicker(context, product: product);
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
          Expanded(
            child: productState.items.isEmpty && productState.loading
                ? const Center(child: CircularProgressIndicator())
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
                      return Container(
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
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppTheme.bgLight,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.inventory_2_outlined, color: AppTheme.brandBlue, size: 40),
                                    ),
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
                                  formatRupiah(product.sellingPriceNum),
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
                                    const Text(
                                      "Tersedia",
                                      style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.brandBlue,
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
