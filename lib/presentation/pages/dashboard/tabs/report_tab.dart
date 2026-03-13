import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/presentation/pages/transactions/transaction_history_page.dart';
import 'package:pos_mobile/presentation/providers/tenant_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

class ReportTab extends ConsumerWidget {
  const ReportTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantAsync = ref.watch(tenantProvider);
    final businessType = tenantAsync.valueOrNull?.businessType;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Laporan & Riwayat",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          if (businessType == 'laundry' || businessType == null)
            _ReportMenuCard(
              title: "Riwayat Transaksi Layanan",
              subtitle: "Lihat daftar transaksi jasa laundry",
              icon: Icons.miscellaneous_services_outlined,
              color: Colors.purple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TransactionHistoryListPage(transactionType: 'service'),
                  ),
                );
              },
            ),
          
          const SizedBox(height: 16),
          
          if (businessType != 'laundry' || businessType == null)
            _ReportMenuCard(
              title: "Riwayat Transaksi Produk",
              subtitle: "Lihat daftar penjualan barang/produk",
              icon: Icons.inventory_2_outlined,
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TransactionHistoryListPage(transactionType: 'sale'),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ReportMenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ReportMenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
