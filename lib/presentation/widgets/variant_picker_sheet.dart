import 'package:flutter/material.dart';
import 'package:pos_mobile/data/models/product_model.dart';
import 'package:pos_mobile/data/models/product_variant_model.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

/// Bottom sheet untuk memilih variant/ukuran sebuah produk.
/// Mengembalikan [ProductVariant] yang dipilih, atau null bila dibatalkan.
Future<ProductVariant?> showVariantPicker(
  BuildContext context, {
  required Product product,
  required List<ProductVariant> variants,
}) {
  return showModalBottomSheet<ProductVariant>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _VariantPickerSheet(product: product, variants: variants),
  );
}

class _VariantPickerSheet extends StatelessWidget {
  final Product product;
  final List<ProductVariant> variants;

  const _VariantPickerSheet({required this.product, required this.variants});

  @override
  Widget build(BuildContext context) {
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
              itemCount: variants.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderLight),
              itemBuilder: (context, index) {
                final v = variants[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  title: Text(v.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  trailing: Text(
                    formatRupiah(v.sellingPriceNum),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.brandBlue),
                  ),
                  onTap: () => Navigator.pop(context, v),
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
