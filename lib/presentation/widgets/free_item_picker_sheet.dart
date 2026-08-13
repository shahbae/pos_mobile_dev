import 'package:flutter/material.dart';
import 'package:pos_mobile/data/models/product_model.dart';
import 'package:pos_mobile/presentation/providers/product_transaction_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

/// Bottom sheet untuk memilih produk yang digratiskan (bonus promo), diambil
/// dari ISI KERANJANG. Mengembalikan [Product] terpilih, atau null bila
/// dibatalkan. Variannya dipilih setelah ini oleh pemanggil — kasir tetap boleh
/// menggratiskan varian lain dari produk yang sama (mis. pesan "XL Normal",
/// bonusnya "XL Less sugar").
///
/// [items] sudah disaring pemanggil ke baris keranjang yang boleh digratiskan:
/// kategorinya `freeable` dan harganya sama dengan item termurah di keranjang
/// (aturan BE: item gratis tidak boleh lebih mahal dari item termurah). Baris
/// dengan produk yang sama digabung di sini.
Future<Product?> showFreeItemPicker(
  BuildContext context, {
  required List<CartItem> items,
}) {
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _FreeItemPickerSheet(items: items),
  );
}

/// Satu produk yang bisa digratiskan, beserta jumlahnya di keranjang.
class _FreeableProduct {
  final Product product;
  final num unitPrice;
  final int qtyInCart;

  const _FreeableProduct({
    required this.product,
    required this.unitPrice,
    required this.qtyInCart,
  });
}

class _FreeItemPickerSheet extends StatelessWidget {
  final List<CartItem> items;

  const _FreeItemPickerSheet({required this.items});

  /// Gabungkan baris keranjang per produk — kasir memilih produknya dulu,
  /// variannya di langkah berikutnya.
  List<_FreeableProduct> get _products {
    final byProduct = <int, _FreeableProduct>{};
    for (final item in items) {
      final existing = byProduct[item.product.id];
      byProduct[item.product.id] = _FreeableProduct(
        product: item.product,
        unitPrice: existing == null
            ? item.unitPrice
            : (item.unitPrice < existing.unitPrice ? item.unitPrice : existing.unitPrice),
        qtyInCart: (existing?.qtyInCart ?? 0) + item.quantity,
      );
    }
    return byProduct.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final products = _products;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Pilih Item Gratis",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    const Text(
                      "Hanya item termurah di keranjang yang bisa digratiskan.",
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: products.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                            "Tidak ada item di keranjang yang bisa digratiskan.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: products.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppTheme.borderLight),
                      itemBuilder: (context, i) {
                        final p = products[i];
                        return ListTile(
                          title: Text(p.product.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          subtitle: Text(
                            p.product.hasVariants
                                ? "${formatRupiah(p.unitPrice)} • di keranjang: ${p.qtyInCart} • pilih varian"
                                : "${formatRupiah(p.unitPrice)} • di keranjang: ${p.qtyInCart}",
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          trailing:
                              const Icon(Icons.add_circle_outline, color: AppTheme.brandBlue),
                          onTap: () => Navigator.pop(context, p.product),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
