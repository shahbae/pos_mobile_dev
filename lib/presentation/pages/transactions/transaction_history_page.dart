import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/presentation/providers/transaction_history_provider.dart';
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
    final title = widget.transactionType == 'service' 
        ? "Riwayat Transaksi Layanan" 
        : widget.transactionType == 'sale' 
            ? "Riwayat Transaksi Produk" 
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
            color: transaction.transactionType == 'service' 
                ? Colors.purple.withOpacity(0.1) 
                : Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            transaction.transactionType == 'service' 
                ? Icons.miscellaneous_services_outlined 
                : Icons.inventory_2_outlined,
            color: transaction.transactionType == 'service' ? Colors.purple : Colors.blue,
          ),
        ),
        title: Text(
          transaction.invoiceNumber,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                color: transaction.status == 'paid' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                transaction.status.toUpperCase(),
                style: TextStyle(
                  color: transaction.status == 'paid' ? Colors.green : Colors.orange,
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
          _DetailRow(label: "Tipe", value: transaction.transactionType == 'service' ? "Layanan" : "Produk"),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor)),
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
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    final state = ref.read(transactionHistoryProvider);
    _type = widget.fixedType ?? state.transactionType;
    _from = state.from;
    _to = state.to;
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
                     ref.read(transactionHistoryProvider.notifier).setFilter(transactionType: widget.fixedType);
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
            Row(
              children: [
                _FilterChip(
                  label: "Semua",
                  selected: _type == null,
                  onSelected: (v) => setState(() => _type = null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: "Produk",
                  selected: _type == 'sale',
                  onSelected: (v) => setState(() => _type = 'sale'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: "Layanan",
                  selected: _type == 'service',
                  onSelected: (v) => setState(() => _type = 'service'),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          const Text("Rentang Waktu", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DatePickerButton(
                  label: "Dari",
                  date: _from,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _from ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _from = picked);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DatePickerButton(
                  label: "Sampai",
                  date: _to,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _to ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _to = picked);
                  },
                ),
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
                  from: _from,
                  to: _to,
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

class _DatePickerButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DatePickerButton({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              date != null ? DateFormat('dd/MM/yyyy').format(date!) : "-",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
