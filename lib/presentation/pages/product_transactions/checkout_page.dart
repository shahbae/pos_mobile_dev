import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/presentation/providers/product_transaction_provider.dart';
import 'package:pos_mobile/presentation/pages/product_transactions/transaction_success_page.dart';
import 'package:pos_mobile/utils/currency.dart';
import 'package:pos_mobile/core/utils/currency_input_formatter.dart';

/// Metode pembayaran sesuai BE: CASH | TRANSFER | QRIS | DEBIT | CREDIT | EWALLET
class _PayMethod {
  final String value;
  final String label;
  final IconData icon;
  const _PayMethod(this.value, this.label, this.icon);
}

const _payMethods = <_PayMethod>[
  _PayMethod('CASH', 'Tunai', Icons.payments_outlined),
  _PayMethod('TRANSFER', 'Transfer', Icons.account_balance_outlined),
  _PayMethod('QRIS', 'QRIS', Icons.qr_code_2_outlined),
  _PayMethod('DEBIT', 'Debit', Icons.credit_card_outlined),
  _PayMethod('CREDIT', 'Kredit', Icons.credit_score_outlined),
  _PayMethod('EWALLET', 'E-Wallet', Icons.account_balance_wallet_outlined),
];

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _paymentRefController = TextEditingController();
  String _paymentMethod = 'CASH';

  bool get _isCash => _paymentMethod == 'CASH';

  @override
  void initState() {
    super.initState();
    final total = ref.read(productTransactionProvider).total;
    final formatter = NumberFormat.decimalPattern('id_ID');
    _paidAmountController.text = formatter.format(total);
  }

  @override
  void dispose() {
    _paidAmountController.dispose();
    _customerNameController.dispose();
    _paymentRefController.dispose();
    super.dispose();
  }

  Future<void> _submit(double total) async {
    final rawPaid = _paidAmountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final paidValue = int.tryParse(rawPaid) ?? 0;

    if (paidValue < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Jumlah bayar kurang dari total belanja"),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_isCash && _paymentRefController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Nomor referensi pembayaran wajib diisi untuk non-tunai"),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await ref.read(productTransactionProvider.notifier).submitTransaction(
          paymentMethod: _paymentMethod,
          paid: paidValue,
          discount: 0,
          paymentRef: _isCash ? null : _paymentRefController.text.trim(),
          customerName: _customerNameController.text.trim().isEmpty
              ? null
              : _customerNameController.text.trim(),
        );

    if (!mounted) return;
    final newState = ref.read(productTransactionProvider);
    if (newState.lastResponse != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionSuccessPage(response: newState.lastResponse!),
        ),
      );
    } else if (newState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal: ${newState.error}"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(productTransactionProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text("Konfirmasi Pembayaran"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Atas Nama (opsional, free text) ──
            const Text("Atas Nama (Opsional)",
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: TextField(
                controller: _customerNameController,
                decoration: const InputDecoration(
                  hintText: "Nama pelanggan",
                  prefixIcon: Icon(Icons.person_outline, color: AppTheme.brandBlue),
                  border: InputBorder.none,
                ),
              ),
            ),
            const Divider(height: 32, color: AppTheme.borderLight),

            // ── Ringkasan Pesanan ──
            const Text("Ringkasan Pesanan",
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cartState.items.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: AppTheme.borderLight, height: 1),
                itemBuilder: (context, index) {
                  final item = cartState.items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.product.name,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                              const SizedBox(height: 2),
                              Text(formatRupiah(item.product.sellingPriceNum),
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.bgLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              _QtyButton(
                                icon: Icons.remove,
                                onTap: () => ref
                                    .read(productTransactionProvider.notifier)
                                    .updateQuantity(item.product.id, item.quantity - 1),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text("${item.quantity}",
                                    style: const TextStyle(
                                        color: AppTheme.brandBlue, fontWeight: FontWeight.w800, fontSize: 15)),
                              ),
                              _QtyButton(
                                icon: Icons.add,
                                onTap: () => ref
                                    .read(productTransactionProvider.notifier)
                                    .updateQuantity(item.product.id, item.quantity + 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(formatRupiah(item.subtotal),
                            style: const TextStyle(
                                color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),

            // ── Metode Pembayaran ──
            const Text("Metode Pembayaran",
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
              children: _payMethods
                  .map((m) => _PaymentMethodCard(
                        label: m.label,
                        icon: m.icon,
                        isSelected: _paymentMethod == m.value,
                        onTap: () => setState(() => _paymentMethod = m.value),
                      ))
                  .toList(),
            ),

            // ── Nomor referensi (non-cash) ──
            if (!_isCash) ...[
              const SizedBox(height: 24),
              const Text("Nomor Referensi",
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: TextField(
                  controller: _paymentRefController,
                  decoration: const InputDecoration(
                    hintText: "No. ref / approval code",
                    prefixIcon: Icon(Icons.confirmation_number_outlined, color: AppTheme.brandBlue),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // ── Jumlah Bayar ──
            const Text("Jumlah Bayar",
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: TextField(
                controller: _paidAmountController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                inputFormatters: [CurrencyInputFormatter()],
                style: const TextStyle(color: AppTheme.brandBlue, fontSize: 28, fontWeight: FontWeight.w800),
                decoration: const InputDecoration(
                  prefixText: "Rp ",
                  prefixStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 20, fontWeight: FontWeight.w600),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 48),

            // ── Tombol bayar ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: cartState.isLoading ? null : () => _submit(cartState.total),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandBlue,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 8,
                  shadowColor: AppTheme.brandBlue.withOpacity(0.4),
                ),
                child: cartState.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("Konfirmasi & Bayar ${formatRupiah(cartState.total)}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.brandBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.brandBlue : AppTheme.borderLight,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.brandBlue.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : AppTheme.textSecondary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 18, color: AppTheme.brandBlue),
      ),
    );
  }
}
