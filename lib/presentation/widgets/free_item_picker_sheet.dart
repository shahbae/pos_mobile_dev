import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/product_model.dart';
import 'package:pos_mobile/presentation/providers/product_pagination_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';
import 'package:pos_mobile/utils/xl_promo.dart';

/// Bottom sheet untuk memilih menu yang digratiskan (bonus promo).
/// Mengembalikan [Product] terpilih, atau null bila dibatalkan. Variannya
/// dipilih setelah ini oleh pemanggil.
///
/// Menunya diambil dari katalog POS yang sudah dimuat, bukan panggilan API
/// tersendiri — katalog itu sudah memuat seluruh halaman dan sudah membawa
/// penanda siap per cabang, jadi menu yang bahannya habis bisa disaring di
/// sini tanpa request tambahan.
///
/// Yang ditawarkan: menu berkategori `freeable`, ukuran XL, siap dibuat, dan
/// harganya ≤ [maxPrice] — batas itu adalah minuman termurah di keranjang.
/// Tidak harus menu yang dipesan: pelanggan boleh minta teh yang tidak ada di
/// pesanannya, asal tidak lebih mahal dari yang termurah tadi.
Future<Product?> showFreeItemPicker(
  BuildContext context, {
  required num maxPrice,
}) {
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _FreeItemPickerSheet(maxPrice: maxPrice),
  );
}

/// True bila [p] boleh dijadikan bonus dengan batas harga [maxPrice].
/// Untuk produk bervarian, cukup ada satu varian XL yang siap dan masuk batas.
bool _isFreeable(Product p, num maxPrice) {
  if (!p.categoryFreeable || !p.ready) return false;
  if (p.hasVariants) {
    return p.variants.any(
      (v) => nameHasXL(v.name) && v.ready && v.sellingPriceNum <= maxPrice,
    );
  }
  return nameHasXL(p.name) && p.sellingPriceNum <= maxPrice;
}

/// Harga termurah yang bisa diambil dari [p] dalam batas [maxPrice] — dipakai
/// untuk label, supaya kasir tahu nilai gratisannya sebelum masuk ke varian.
num _lowestPrice(Product p, num maxPrice) {
  if (!p.hasVariants) return p.sellingPriceNum;
  final harga = p.variants
      .where((v) => nameHasXL(v.name) && v.ready && v.sellingPriceNum <= maxPrice)
      .map((v) => v.sellingPriceNum);
  return harga.reduce((a, b) => a < b ? a : b);
}

class _FreeItemPickerSheet extends ConsumerStatefulWidget {
  final num maxPrice;

  const _FreeItemPickerSheet({required this.maxPrice});

  @override
  ConsumerState<_FreeItemPickerSheet> createState() => _FreeItemPickerSheetState();
}

class _FreeItemPickerSheetState extends ConsumerState<_FreeItemPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    // Ditonton, bukan sekadar dibaca: kalau katalog kebetulan sudah dilepas,
    // menontonnya membangun ulang notifier-nya yang langsung memuat sendiri.
    final catalog = ref.watch(productPaginationProvider);

    final keyword = _search.trim().toLowerCase();
    final products = catalog.allItems
        .where((p) => _isFreeable(p, widget.maxPrice))
        .where((p) => keyword.isEmpty || p.name.toLowerCase().contains(keyword))
        .toList()
      ..sort((a, b) => _lowestPrice(a, widget.maxPrice)
          .compareTo(_lowestPrice(b, widget.maxPrice)));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.92,
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Pilih Item Gratis",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        "Maks seharga item termurah di keranjang: "
                        "${formatRupiah(widget.maxPrice)}",
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: "Cari menu...",
                    prefixIcon: const Icon(Icons.search, color: AppTheme.brandBlue),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _body(products, catalog, scrollController),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _body(
    List<Product> products,
    ProductPaginationState catalog,
    ScrollController scrollController,
  ) {
    if (catalog.loading && catalog.allItems.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _search.trim().isNotEmpty
                ? "Menu itu tidak bisa digratiskan, atau harganya di atas "
                    "${formatRupiah(widget.maxPrice)}."
                : "Tidak ada menu XL yang bisa digratiskan — semuanya di atas "
                    "${formatRupiah(widget.maxPrice)} atau sedang habis.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      itemCount: products.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppTheme.borderLight),
      itemBuilder: (context, i) {
        final p = products[i];
        return ListTile(
          title: Text(p.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          subtitle: Text(
            p.hasVariants
                ? "${formatRupiah(_lowestPrice(p, widget.maxPrice))} • pilih varian"
                : formatRupiah(p.sellingPriceNum),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          trailing: const Icon(Icons.add_circle_outline, color: AppTheme.brandBlue),
          onTap: () => Navigator.pop(context, p),
        );
      },
    );
  }
}
