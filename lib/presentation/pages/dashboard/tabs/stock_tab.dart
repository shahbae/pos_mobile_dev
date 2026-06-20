import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/presentation/pages/products/product_list_page.dart';
import 'package:pos_mobile/presentation/pages/purchases/purchase_list_page.dart';
import 'package:pos_mobile/presentation/pages/stock_movements/stock_movement_list_page.dart';
import 'package:pos_mobile/presentation/pages/stock_audits/stock_audit_list_page.dart';
import 'package:pos_mobile/presentation/pages/stock_levels/stock_level_page.dart';
import 'package:pos_mobile/presentation/pages/topping_stock/topping_stock_page.dart';
import 'package:pos_mobile/presentation/pages/topping_stock/topping_stock_movement_page.dart';
import 'package:pos_mobile/presentation/pages/expenses/expense_list_page.dart';
import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

class StockTab extends ConsumerWidget {
  const StockTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final features = featuresForRole(ref.watch(authProvider).role);

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
          if (features.contains(AppFeature.products)) ...[
            const SizedBox(height: 16),
            _menuItem(
              context,
              icon: Icons.inventory_2_outlined,
              title: "Produk",
              subtitle: "Kelola daftar produk, harga dan stok",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductListPage()),
              ),
            ),
          ],
          if (features.contains(AppFeature.purchases)) ...[
            const SizedBox(height: 16),
            _menuItem(
              context,
              icon: Icons.shopping_cart_checkout_outlined,
              title: "Pembelian",
              subtitle: "Catat transaksi pembelian ke supplier",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PurchaseListPage()),
              ),
            ),
          ],
          if (features.contains(AppFeature.stockMaterial)) ...[
            const SizedBox(height: 16),
            _menuItem(
              context,
              icon: Icons.inventory_outlined,
              title: "Stok Material",
              subtitle: "Lihat saldo & sesuaikan stok material",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StockLevelPage()),
              ),
            ),
          ],
          if (features.contains(AppFeature.stockTopping)) ...[
            const SizedBox(height: 16),
            _menuItem(
              context,
              icon: Icons.icecream_outlined,
              title: "Stok Topping",
              subtitle: "Lihat saldo & sesuaikan stok topping",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ToppingStockPage()),
              ),
            ),
          ],
          if (features.contains(AppFeature.stockMovements)) ...[
            const SizedBox(height: 16),
            _menuItem(
              context,
              icon: Icons.history_outlined,
              title: "Riwayat Mutasi Stok",
              subtitle: "Lihat keluar / masuk stok",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StockMovementListPage()),
              ),
            ),
          ],
          if (features.contains(AppFeature.toppingMovements)) ...[
            const SizedBox(height: 16),
            _menuItem(
              context,
              icon: Icons.history_toggle_off_outlined,
              title: "Riwayat Stok Topping",
              subtitle: "Lihat keluar / masuk stok topping",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ToppingStockMovementPage()),
              ),
            ),
          ],
          if (features.contains(AppFeature.stockAudit)) ...[
            const SizedBox(height: 16),
            _menuItem(
              context,
              icon: Icons.fact_check_outlined,
              title: "Audit Stok",
              subtitle: "Hitung fisik & sesuaikan stok material",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StockAuditListPage()),
              ),
            ),
          ],
          if (features.contains(AppFeature.expenses)) ...[
            const SizedBox(height: 16),
            _menuItem(
              context,
              icon: Icons.money_off_csred_outlined,
              title: "Pengeluaran",
              subtitle: "Catat biaya operasional & lainnya",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpenseListPage()),
              ),
            ),
          ],
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
