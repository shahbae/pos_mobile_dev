import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/presentation/providers/transaction_history_provider.dart';
import 'package:pos_mobile/presentation/pages/transactions/receipt_page.dart';
import 'package:pos_mobile/utils/currency.dart';

class TransactionHistoryListPage extends ConsumerStatefulWidget {
  final String? transactionType;
  const TransactionHistoryListPage({super.key, this.transactionType});

  @override
  ConsumerState<TransactionHistoryListPage> createState() => _TransactionHistoryListPageState();
}

class _TransactionHistoryListPageState extends ConsumerState<TransactionHistoryListPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Set initial filter if transactionType is provided
    if (widget.transactionType != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(transactionHistoryProvider.notifier).setFilter(
          transactionType: widget.transactionType,
        );
      });
    }
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
    final title = widget.transactionType == 'pos'
        ? "Riwayat Penjualan"
        : widget.transactionType == 'purchase'
            ? "Riwayat Pembelian"
            : "Riwayat Transaksi";

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_outlined),
            onPressed: () => _showFilterBottomSheet(context),
          ),
        ],
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

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _FilterBottomSheet(fixedType: widget.transactionType);
      },
    );
  }
}

class _TransactionItemCard extends StatelessWidget {
  final dynamic transaction;

  const _TransactionItemCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(transaction.createdAt);
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(date);

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
            color: transaction.isPurchase
                ? Colors.orange.withOpacity(0.1)
                : AppTheme.brandBlue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            transaction.isPurchase
                ? Icons.shopping_cart_checkout_outlined
                : Icons.inventory_2_outlined,
            color: transaction.isPurchase ? Colors.orange : AppTheme.brandBlue,
          ),
        ),
        title: Text(
          transaction.isPurchase
              ? (transaction.note != null && (transaction.note as String).isNotEmpty
                  ? transaction.note
                  : 'Pembelian #${transaction.id}')
              : (transaction.invoiceNumber.isNotEmpty
                  ? transaction.invoiceNumber
                  : 'Transaksi #${transaction.id}'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatRupiah(transaction.totalAmountNum),
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.brandBlue),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: transaction.isPurchase
                    ? Colors.orange.withOpacity(0.1)
                    : AppTheme.brandBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                transaction.isPurchase ? 'PEMBELIAN' : 'PENJUALAN',
                style: TextStyle(
                  color: transaction.isPurchase ? Colors.orange : AppTheme.brandBlue,
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
    final paymentsAsync = ref.watch(paymentDetailProvider(transaction.id));

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
          _DetailRow(label: "No. Invoice", value: transaction.invoiceNumber),
          _DetailRow(label: "Tipe", value: transaction.isPurchase ? "Pembelian" : "Penjualan"),
          _DetailRow(label: "Status", value: transaction.status.toUpperCase()),
          _DetailRow(label: "Total Tagihan", value: formatRupiah(transaction.totalAmountNum), valueColor: AppTheme.brandBlue),
          const SizedBox(height: 24),
          const Text(
            "Detail Pembayaran",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: paymentsAsync.when(
              data: (payments) => payments.isEmpty 
                ? const Center(child: Text("Belum ada data pembayaran"))
                : ListView.builder(
                    itemCount: payments.length,
                    itemBuilder: (context, index) {
                      final p = payments[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.bgLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _DetailRow(label: "Metode", value: p.paymentMethod.toUpperCase()),
                            _DetailRow(label: "Bayar", value: formatRupiah(p.amountPaidNum)),
                            _DetailRow(label: "Kembalian", value: formatRupiah(p.changeAmountNum)),
                          ],
                        ),
                      );
                    },
                  ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text("Gagal memuat data pembayaran: $err")),
            ),
          ),
          const SizedBox(height: 8),
          if (!transaction.isPurchase && transaction.invoiceNumber.toString().isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReceiptPage(invoiceNo: transaction.invoiceNumber),
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

class _FilterBottomSheet extends ConsumerStatefulWidget {
  final String? fixedType;
  const _FilterBottomSheet({this.fixedType});

  @override
  ConsumerState<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<_FilterBottomSheet> {
  String? _type;
  String? _status;

  @override
  void initState() {
    super.initState();
    final state = ref.read(transactionHistoryProvider);
    _type = widget.fixedType ?? state.transactionTypes?.first;
    _status = state.status;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Filter Transaksi",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  ref.read(transactionHistoryProvider.notifier).resetFilters();
                  if (widget.fixedType != null) {
                    ref.read(transactionHistoryProvider.notifier).setFilter(
                      transactionType: widget.fixedType,
                    );
                  }
                  Navigator.pop(context);
                },
                child: const Text("Reset", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (widget.fixedType == null) ...[
            const Text("Tipe Transaksi", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(
                  label: "Semua",
                  selected: _type == null,
                  onSelected: (v) => setState(() => _type = null),
                ),
                _FilterChip(
                  label: "Penjualan",
                  selected: _type == 'pos',
                  onSelected: (v) => setState(() => _type = 'pos'),
                ),
                _FilterChip(
                  label: "Pembelian",
                  selected: _type == 'purchase',
                  onSelected: (v) => setState(() => _type = 'purchase'),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          const Text("Status", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: "Semua",
                selected: _status == null,
                onSelected: (v) => setState(() => _status = null),
              ),
              _FilterChip(
                label: "Paid",
                selected: _status == 'paid',
                onSelected: (v) => setState(() => _status = 'paid'),
              ),
              _FilterChip(
                label: "Unpaid",
                selected: _status == 'unpaid',
                onSelected: (v) => setState(() => _status = 'unpaid'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                 ref.read(transactionHistoryProvider.notifier).setFilter(
                  transactionType: _type,
                  status: _status,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("Terapkan Filter", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Function(bool) onSelected;

  const _FilterChip({required this.label, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: AppTheme.brandBlue.withOpacity(0.2),
      labelStyle: TextStyle(
        color: selected ? AppTheme.brandBlue : Colors.black,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

