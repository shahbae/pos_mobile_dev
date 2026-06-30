import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/purchase_model.dart';
import '../../providers/purchase_provider.dart';
import '../../../utils/currency.dart';

class PurchaseDetailPage extends ConsumerWidget {
  final int purchaseId;

  const PurchaseDetailPage({super.key, required this.purchaseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncData = ref.watch(purchaseDetailProvider(purchaseId));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text("Detail Pembelian"),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: asyncData.when(
        data: (purchase) => _buildContent(context, purchase),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Gagal memuat detail pembelian:\n$e',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade400),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, PurchaseModel purchase) {
    final theme = Theme.of(context);
    final amt = num.tryParse(purchase.totalAmount ?? '0') ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =====================
          // HEADER NAME
          // =====================
          Text(
            "Pembelian #${purchase.id}",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 6),

          Text(
            "Informasi nota pembelian",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 24),

          // =====================
          // RESUME CARD
          // =====================
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _row("Pemasok", purchase.supplierName ?? "-"),
                  _row("Catatan", purchase.note ?? "-"),
                  _row("Tanggal", _formatDate(purchase.createdAt)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // =====================
          // ITEMS LIST
          // =====================
          const Text(
            "Daftar Item",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          if (purchase.items == null || purchase.items!.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Center(child: Text("Tidak ada item didalam catatan pembelian.")),
            )
          else
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: purchase.items!.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final item = purchase.items![i];
                final unitCost = num.tryParse(item.unitCost ?? '0') ?? 0;
                final subtotal = num.tryParse(item.subtotal ?? '0') ?? 0;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.typeLabel == 'Topping' ? Icons.icecream_outlined : Icons.inventory_2_outlined,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, height: 1.25),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (item.typeLabel != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(item.typeLabel!,
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Text(
                                    // Pakai ringkasan template bila ada
                                    // (mis. "2 Lusin (= 2400 gram)"), jika tidak
                                    // fallback ke "qty x unit cost".
                                    item.packSummary ??
                                        "${item.quantityDisplay} x ${formatRupiah(unitCost)}",
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatRupiah(subtotal),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 28),

          // =====================
          // TOTAL
          // =====================
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Tagihan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                ),
                Text(
                  formatRupiah(amt),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: theme.colorScheme.primary),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}
