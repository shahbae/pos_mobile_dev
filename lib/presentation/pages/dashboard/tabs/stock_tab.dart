import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/presentation/pages/products/product_list_page.dart';

class StockTab extends ConsumerWidget {
  const StockTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Manajemen Stok",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                "Kelola produk & inventory bisnis Anda",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: ListView(
                  children: [
                    _menuItem(
                      context,
                      icon: Icons.inventory_2_outlined,
                      title: "Produk",
                      subtitle: "Kelola daftar produk, harga dan stok",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProductListPage(),
                          ),
                        );
                      },
                    ),

                    _menuItem(
                      context,
                      icon: Icons.playlist_add_check_circle_outlined,
                      title: "Penyesuaian Stok",
                      subtitle: "Catat perubahan stok barang",
                      disabled: true,
                    ),

                    _menuItem(
                      context,
                      icon: Icons.history_outlined,
                      title: "Riwayat Mutasi Stok",
                      subtitle: "Lihat keluar / masuk stok",
                      disabled: true,
                    ),

                    _menuItem(
                      context,
                      icon: Icons.category_outlined,
                      title: "Kategori Produk",
                      subtitle: "Kelola pengelompokan produk",
                      disabled: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Card(
        elevation: 0, // flat & modern
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: ListTile(
          onTap: disabled ? null : onTap,
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          trailing: Icon(Icons.chevron_right, color: Colors.grey[500]),
        ),
      ),
    );
  }
}
