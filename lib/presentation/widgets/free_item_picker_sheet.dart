import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/product_model.dart';
import 'package:pos_mobile/presentation/providers/product_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

/// Bottom sheet untuk memilih produk `freeable` sebagai item gratis (bonus).
/// Mengembalikan [Product] terpilih, atau null bila dibatalkan. Pemilihan
/// varian dilakukan setelahnya oleh pemanggil (bila produk punya varian).
Future<Product?> showFreeItemPicker(BuildContext context) {
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _FreeItemPickerSheet(),
  );
}

class _FreeItemPickerSheet extends ConsumerStatefulWidget {
  const _FreeItemPickerSheet();

  @override
  ConsumerState<_FreeItemPickerSheet> createState() => _FreeItemPickerSheetState();
}

class _FreeItemPickerSheetState extends ConsumerState<_FreeItemPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(freeableProductsProvider(_search.isEmpty ? null : _search));

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
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Pilih Item Gratis",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ),
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
                child: productsAsync.when(
                  data: (products) {
                    if (products.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text("Tidak ada menu yang bisa digratiskan.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary)),
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
                            p.hasVariants ? "Pilih varian" : formatRupiah(p.sellingPriceNum),
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          trailing:
                              const Icon(Icons.add_circle_outline, color: AppTheme.brandBlue),
                          onTap: () => Navigator.pop(context, p),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text("Gagal memuat menu: $e",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.danger)),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
