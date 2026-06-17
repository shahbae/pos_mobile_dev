import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/presentation/providers/transaction_history_provider.dart';
import 'package:pos_mobile/data/repositories/receipt_repository.dart';
import 'package:pos_mobile/presentation/pages/transactions/receipt_page.dart';
import 'package:pos_mobile/utils/currency.dart';

class TransactionHistoryListPage extends ConsumerStatefulWidget {
  const TransactionHistoryListPage({super.key});

  @override
  ConsumerState<TransactionHistoryListPage> createState() => _TransactionHistoryListPageState();
}

class _TransactionHistoryListPageState extends ConsumerState<TransactionHistoryListPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(transactionHistoryProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionHistoryProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text("Riwayat Penjualan"),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(transactionHistoryProvider.notifier).load(reset: true),
        child: state.items.isEmpty && state.loading
            ? const Center(child: CircularProgressIndicator())
            : state.items.isEmpty
                ? const Center(child: Text("Tidak ada transaksi"))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: state.items.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.items.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final transaction = state.items[index];
                      return _TransactionItemCard(transaction: transaction);
                    },
                  ),
      ),
    );
  }

}

class _TransactionItemCard extends StatelessWidget {
  final dynamic transaction;

  const _TransactionItemCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    // txn_date ber-offset (mis. +07:00) → DateTime.parse menghasilkan UTC,
    // jadi konversi ke waktu lokal dulu agar jam tampil sesuai WIB.
    final date = DateTime.tryParse(transaction.txnDate)?.toLocal();
    final formattedDate =
        date != null ? DateFormat('dd MMM yyyy, HH:mm').format(date) : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () {
          // Navigate to detail
          _showTransactionDetail(context, transaction);
        },
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.brandBlue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.inventory_2_outlined,
            color: AppTheme.brandBlue,
          ),
        ),
        title: Text(
          transaction.refOrEmpty.isNotEmpty
              ? transaction.refOrEmpty
              : 'Transaksi #${transaction.id}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            if (transaction.actorName != null && (transaction.actorName as String).isNotEmpty)
              Text('Kasir: ${transaction.actorName}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatRupiah(transaction.amountNum),
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.brandBlue),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.brandBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'PENJUALAN',
                style: TextStyle(
                  color: AppTheme.brandBlue,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetail(BuildContext context, dynamic transaction) {
     showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TransactionDetailBottomSheet(transaction: transaction),
    );
  }
}

class _TransactionDetailBottomSheet extends ConsumerWidget {
  final dynamic transaction;
  const _TransactionDetailBottomSheet({required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceNo = transaction.refOrEmpty as String;
    final txnAt = DateTime.tryParse(transaction.txnDate)?.toLocal();
    final txnText =
        txnAt != null ? DateFormat('dd MMM yyyy, HH:mm').format(txnAt) : '-';

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Detail Transaksi",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),
          _DetailRow(label: "No. Invoice", value: invoiceNo.isNotEmpty ? invoiceNo : '-'),
          _DetailRow(label: "Waktu", value: txnText),
          if (transaction.actorName != null && (transaction.actorName as String).isNotEmpty)
            _DetailRow(label: "Kasir", value: transaction.actorName),
          if (transaction.branchName != null && (transaction.branchName as String).isNotEmpty)
            _DetailRow(label: "Cabang", value: transaction.branchName),
          if (transaction.note != null && (transaction.note as String).isNotEmpty)
            _DetailRow(label: "Catatan", value: transaction.note),
          _DetailRow(label: "Total Tagihan", value: formatRupiah(transaction.amountNum), valueColor: AppTheme.brandBlue),
          const SizedBox(height: 24),
          const Text(
            "Detail Pembayaran",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: invoiceNo.isEmpty
                ? const Center(child: Text("Belum ada data pembayaran"))
                // Sumber detail pembayaran = struk (GET /product-transactions/{invoice_no}),
                // karena endpoint /transactions/{id}/payments tidak tersedia di BE.
                : ref.watch(receiptProvider(invoiceNo)).when(
                    data: (r) => SingleChildScrollView(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.bgLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _DetailRow(label: "Metode", value: r.paymentMethod.toUpperCase()),
                            if (r.paymentRef != null && r.paymentRef!.isNotEmpty)
                              _DetailRow(label: "No. Ref", value: r.paymentRef!),
                            _DetailRow(label: "Total", value: formatRupiah(r.total)),
                            _DetailRow(label: "Bayar", value: formatRupiah(r.paid)),
                            _DetailRow(label: "Kembalian", value: formatRupiah(r.change)),
                          ],
                        ),
                      ),
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) =>
                        Center(child: Text("Gagal memuat data pembayaran: $err")),
                  ),
          ),
          const SizedBox(height: 8),
          if (invoiceNo.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReceiptPage(invoiceNo: invoiceNo),
                    ),
                  );
                },
                icon: const Icon(Icons.print_outlined),
                label: const Text("Cetak Nota", style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
