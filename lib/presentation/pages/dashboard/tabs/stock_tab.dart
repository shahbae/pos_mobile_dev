import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/presentation/pages/products/product_list_page.dart';

class StockTab extends ConsumerWidget {
  const StockTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Manajemen Stok",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                "Kelola produk & inventory bisnis Anda",
                style: TextStyle(color: Colors.white70, fontSize: 13),
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
                      disabled: true, // future feature
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
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: Card(
        color: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ListTile(
          onTap: disabled ? null : onTap,
          leading: Icon(icon, color: Colors.white),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.white60),
        ),
      ),
    );
  }
}
