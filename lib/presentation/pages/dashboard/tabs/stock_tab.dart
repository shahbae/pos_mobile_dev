import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/presentation/pages/products/product_list_page.dart';
import 'package:pos_mobile/presentation/pages/product_categories/product_category_list_page.dart';
import 'package:pos_mobile/presentation/pages/services/service_list_page.dart';
import 'package:pos_mobile/presentation/pages/purchases/purchase_list_page.dart';
import 'package:pos_mobile/presentation/pages/stock_movements/stock_movement_list_page.dart';
import 'package:pos_mobile/presentation/pages/expenses/expense_list_page.dart';
import 'package:pos_mobile/theme/app_theme.dart';

class StockTab extends ConsumerWidget {
  const StockTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,

      body: ListView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset + 96),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withOpacity(0.20)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Kelola produk & layanan bisnis Anda",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Kelola stok, transaksi, dan catatan penting lainnya.",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.insights_outlined, color: accent, size: 28),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _menuItem(
            context,
            icon: Icons.inventory_2_outlined,
            title: "Produk",
            subtitle: "Kelola daftar produk, harga dan stok",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductListPage()),
              );
            },
          ),
          const SizedBox(height: 16),
          _menuItem(
            context,
            icon: Icons.design_services_outlined,
            title: "Layanan",
            subtitle: "Kelola tarif layanan dan jasa",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ServiceListPage()),
              );
            },
          ),
          const SizedBox(height: 16),
          _menuItem(
            context,
            icon: Icons.shopping_cart_checkout_outlined,
            title: "Pembelian",
            subtitle: "Catat transaksi pembelian ke supplier",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PurchaseListPage()),
              );
            },
          ),
          const SizedBox(height: 16),
          _menuItem(
            context,
            icon: Icons.history_outlined,
            title: "Riwayat Mutasi Stok",
            subtitle: "Lihat keluar / masuk stok",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StockMovementListPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _menuItem(
            context,
            icon: Icons.category_outlined,
            title: "Kategori Produk",
            subtitle: "Kelola pengelompokan produk",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProductCategoryListPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _menuItem(
            context,
            icon: Icons.money_off_csred_outlined,
            title: "Pengeluaran",
            subtitle: "Catat biaya operasional & lainnya",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpenseListPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool disabled = false,
  }) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.bgLight,
                  border: Border.all(color: AppTheme.borderLight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.chevron_right,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
