import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/presentation/providers/service_transaction_provider.dart';
import 'package:pos_mobile/presentation/pages/service_transactions/service_transaction_success_page.dart';
import 'package:pos_mobile/utils/currency.dart';
import 'package:pos_mobile/core/utils/currency_input_formatter.dart';
import 'package:pos_mobile/data/models/service_model.dart';
import 'package:pos_mobile/presentation/pages/customers/customer_list_page.dart';
import 'package:pos_mobile/data/models/customer_model.dart';

class ServiceCheckoutPage extends ConsumerStatefulWidget {
  const ServiceCheckoutPage({super.key});

  @override
  ConsumerState<ServiceCheckoutPage> createState() =>
      _ServiceCheckoutPageState();
}

class _ServiceCheckoutPageState extends ConsumerState<ServiceCheckoutPage> {
  final TextEditingController _paidAmountController = TextEditingController();
  String _paymentMethod = 'cash';

  @override
  void initState() {
    super.initState();
    final total = ref.read(serviceTransactionProvider).totalPrice;
    final formatter = NumberFormat.decimalPattern('id_ID');
    _paidAmountController.text = formatter.format(total);
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(serviceTransactionProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text("Konfirmasi Pembayaran"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Select Customer
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.person_outline,
                size: 28,
                color: AppTheme.brandBlue,
              ),
              title: Text(
                cartState.selectedCustomer?.name ??
                    'Pilih Pelanggan (Opsional)',
                style: TextStyle(
                  color: cartState.selectedCustomer == null
                      ? Colors.grey
                      : AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: cartState.selectedCustomer != null
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => ref
                          .read(serviceTransactionProvider.notifier)
                          .setCustomer(null),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: () async {
                final Map<String, dynamic>? result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const CustomerListPage(isSelectionMode: true),
                  ),
                );

                if (result != null && result['customer'] != null) {
                  ref
                      .read(serviceTransactionProvider.notifier)
                      .setCustomer(result['customer'] as Customer);
                }
              },
            ),
            const Divider(height: 32, color: AppTheme.borderLight),

            const Text(
              "Ringkasan Layanan",
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
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
                itemCount: cartState.cart.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: AppTheme.borderLight, height: 1),
                itemBuilder: (context, index) {
                  final service = cartState.cart.keys.elementAt(index);
                  final quantity = cartState.cart[service]!;
                  final subtotal = service.priceNum * quantity;

                  String qStr = quantity.toString();
                  if (qStr.endsWith('.0')) {
                    qStr = qStr.substring(0, qStr.length - 2);
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                service.name,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${formatRupiah(service.priceNum)} x $qStr",
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Quantity Controls
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
                                    .read(serviceTransactionProvider.notifier)
                                    .updateQuantity(service, quantity - 1),
                              ),
                              InkWell(
                                onTap: () =>
                                    _showQuantityDialog(context, ref, service),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    qStr,
                                    style: const TextStyle(
                                      color: AppTheme.brandBlue,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                              _QtyButton(
                                icon: Icons.add,
                                onTap: () => ref
                                    .read(serviceTransactionProvider.notifier)
                                    .updateQuantity(service, quantity + 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          formatRupiah(subtotal),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Metode Pembayaran",
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _PaymentMethodCard(
                  label: "Tunai",
                  icon: Icons.payments_outlined,
                  isSelected: _paymentMethod == 'cash',
                  onTap: () => setState(() => _paymentMethod = 'cash'),
                ),
                const SizedBox(width: 16),
                _PaymentMethodCard(
                  label: "QRIS",
                  icon: Icons.account_balance_outlined,
                  isSelected: _paymentMethod == 'bank_transfer',
                  onTap: () => setState(() => _paymentMethod = 'bank_transfer'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              "Jumlah Bayar",
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
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
                style: const TextStyle(
                  color: AppTheme.brandBlue,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
                decoration: const InputDecoration(
                  prefixText: "Rp ",
                  prefixStyle: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: cartState.isLoading
                    ? null
                    : () async {
                        final rawPaidAmount = _paidAmountController.text
                            .replaceAll('.', '');
                        final paidValue = double.tryParse(rawPaidAmount) ?? 0;

                        if (paidValue < cartState.totalPrice) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Jumlah bayar kurang dari total belanja",
                              ),
                              backgroundColor: Colors.orange,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        ref
                            .read(serviceTransactionProvider.notifier)
                            .updatePayment(_paymentMethod, paidValue);

                        try {
                          final res = await ref
                              .read(serviceTransactionProvider.notifier)
                              .checkout();
                          if (mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ServiceTransactionSuccessPage(
                                  invoiceNumber: res.invoiceNumber,
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Gagal: $e"),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandBlue,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 8,
                  shadowColor: AppTheme.brandBlue.withOpacity(0.4),
                ),
                child: cartState.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "Konfirmasi & Bayar ${formatRupiah(cartState.totalPrice)}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showQuantityDialog(
    BuildContext context,
    WidgetRef ref,
    ServiceModel service,
  ) {
    final qtyController = TextEditingController();
    final cartState = ref.read(serviceTransactionProvider);
    if (cartState.cart.containsKey(service)) {
      qtyController.text = cartState.cart[service].toString();
      if (qtyController.text.endsWith('.0')) {
        qtyController.text = qtyController.text.substring(
          0,
          qtyController.text.length - 2,
        );
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("Ubah Jumlah (${service.unitType})"),
          content: TextField(
            controller: qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Misal: 1.5',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref
                    .read(serviceTransactionProvider.notifier)
                    .removeFromCart(service);
                Navigator.pop(ctx);
                if (ref.read(serviceTransactionProvider).cart.isEmpty &&
                    mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text("Hapus", style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandBlue,
              ),
              onPressed: () {
                final val =
                    double.tryParse(qtyController.text.replaceAll(',', '.')) ??
                    0;
                if (val > 0) {
                  ref
                      .read(serviceTransactionProvider.notifier)
                      .updateQuantity(service, val);
                } else {
                  ref
                      .read(serviceTransactionProvider.notifier)
                      .removeFromCart(service);
                }
                Navigator.pop(ctx);
                if (ref.read(serviceTransactionProvider).cart.isEmpty &&
                    mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text(
                "Simpan",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
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
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
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
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
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
