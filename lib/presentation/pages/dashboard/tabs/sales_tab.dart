import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/presentation/pages/product_transactions/product_transaction_page.dart';
import 'package:pos_mobile/presentation/pages/shifts/shift_guard.dart';

class SalesTab extends ConsumerWidget {
  const SalesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          const Text(
            "Mulai Transaksi Produk",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Kelola pesanan pelanggan dengan cepat dan mudah.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              // BE mewajibkan shift aktif untuk membuat transaksi POS.
              final ok = await ensureActiveShift(context, ref);
              if (!ok || !context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductTransactionPage()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text("Transaksi Baru"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
