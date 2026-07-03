import 'package:flutter/material.dart';
import 'package:pos_mobile/data/models/product_model.dart';
import 'package:pos_mobile/data/models/product_variant_model.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

/// Bottom sheet untuk memilih variant/ukuran sebuah produk.
/// Mengembalikan [ProductVariant] yang dipilih, atau null bila dibatalkan.
///
/// [maxPrice] (opsional) membatasi varian yang boleh dipilih ke yang harganya
/// ≤ nilai tsb — dipakai saat memilih item gratis promo (batas item termurah).
Future<ProductVariant?> showVariantPicker(
  BuildContext context, {
  required Product product,
  required List<ProductVariant> variants,
  num? maxPrice,
}) {
  return showModalBottomSheet<ProductVariant>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) =>
        _VariantPickerSheet(product: product, variants: variants, maxPrice: maxPrice),
  );
}

class _VariantPickerSheet extends StatelessWidget {
  final Product product;
  final List<ProductVariant> variants;
  final num? maxPrice;

  const _VariantPickerSheet({
    required this.product,
    required this.variants,
    this.maxPrice,
  });

  @override
  Widget build(BuildContext context) {
    final shown = maxPrice == null
        ? variants
        : variants.where((v) => v.sellingPriceNum <= maxPrice!).toList();
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderLight,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  const Text('Pilih variasi / ukuran',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppTheme.borderLight),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: shown.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderLight),
              itemBuilder: (context, index) {
                final v = shown[index];
                // Varian yang bahannya habis (is_ready == false) tidak bisa dipilih.
                final disabled = !v.ready;
                return ListTile(
                  enabled: !disabled,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(v.name,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: disabled ? AppTheme.textSecondary : AppTheme.textPrimary)),
                      ),
                      if (disabled) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Habis',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.danger)),
                        ),
                      ],
                    ],
                  ),
                  trailing: Text(
                    formatRupiah(v.sellingPriceNum),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: disabled ? AppTheme.textSecondary : AppTheme.brandBlue),
                  ),
                  onTap: disabled ? null : () => Navigator.pop(context, v),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
