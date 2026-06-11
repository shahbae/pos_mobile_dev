import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_mobile/data/models/product_model.dart';
import 'package:pos_mobile/data/models/promo_model.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/presentation/providers/product_transaction_provider.dart';
import 'package:pos_mobile/presentation/providers/promo_provider.dart';
import 'package:pos_mobile/presentation/pages/product_transactions/transaction_success_page.dart';
import 'package:pos_mobile/presentation/widgets/topping_picker_sheet.dart';
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
  num _lastTotal = 0;

  bool get _isCash => _paymentMethod == 'CASH';

  @override
  void initState() {
    super.initState();
    _lastTotal = ref.read(productTransactionProvider).total;
    _paidAmountController.text = NumberFormat.decimalPattern('id_ID').format(_lastTotal);
  }

  @override
  void dispose() {
    _paidAmountController.dispose();
    _customerNameController.dispose();
    _paymentRefController.dispose();
    super.dispose();
  }

  /// Sinkronkan "Jumlah Bayar" mengikuti total bila kasir belum mengubah manual.
  void _syncPaidIfUntouched(num total) {
    final currentRaw = _paidAmountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final lastRaw = _lastTotal.toInt().toString();
    if (currentRaw == lastRaw || currentRaw.isEmpty) {
      _paidAmountController.text = NumberFormat.decimalPattern('id_ID').format(total);
    }
    _lastTotal = total;
  }

  Future<void> _submit(num total) async {
    final rawPaid = _paidAmountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final paidValue = int.tryParse(rawPaid) ?? 0;

    if (paidValue < total) {
      _toast("Jumlah bayar kurang dari total belanja", Colors.orange);
      return;
    }
    if (!_isCash && _paymentRefController.text.trim().isEmpty) {
      _toast("Nomor referensi pembayaran wajib diisi untuk non-tunai", Colors.orange);
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
      _toast("Gagal: ${newState.error}", Colors.red);
    }
  }

  void _toast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _editLine(CartItem item) async {
    final result = await showToppingPicker(
      context,
      product: item.product,
      initialQty: item.quantity,
      initialFree: item.freeToppings,
      initialExtra: item.extraToppings,
    );
    if (result == null) return;
    final notifier = ref.read(productTransactionProvider.notifier);
    notifier.updateLineToppings(
      item.lineId,
      freeToppings: result.freeToppings,
      extraToppings: result.extraToppings,
    );
    notifier.updateQuantity(item.lineId, result.quantity);
  }

  /// Gandakan baris bertopping lalu langsung buka picker untuk diubah → baris baru.
  Future<void> _duplicateAndEdit(CartItem item) async {
    final result = await showToppingPicker(
      context,
      product: item.product,
      initialQty: 1,
      initialFree: item.freeToppings,
      initialExtra: item.extraToppings,
    );
    if (result == null) return;
    ref.read(productTransactionProvider.notifier).addLineWithToppings(
          item.product,
          quantity: result.quantity,
          freeToppings: result.freeToppings,
          extraToppings: result.extraToppings,
        );
  }

  Widget _lineAction(IconData icon, String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: AppTheme.brandBlue,
      ),
      icon: Icon(icon, size: 16, color: AppTheme.brandBlue),
      label: Text(label,
          style: const TextStyle(color: AppTheme.brandBlue, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(productTransactionProvider);
    final promosAsync = ref.watch(activePromosProvider);

    // Jaga field "Jumlah Bayar" tetap sinkron dengan total saat berubah.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncPaidIfUntouched(cartState.total);
    });

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text("Konfirmasi Pembayaran"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Atas Nama ──
            _sectionTitle("Atas Nama (Opsional)", 16),
            const SizedBox(height: 12),
            _whiteBox(
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
            _sectionTitle("Ringkasan Pesanan", 18),
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
                separatorBuilder: (_, __) => const Divider(color: AppTheme.borderLight, height: 1),
                itemBuilder: (context, index) => _cartRow(cartState.items[index]),
              ),
            ),
            const SizedBox(height: 24),

            // ── Promo ──
            promosAsync.maybeWhen(
              data: (promos) => _promoSection(cartState, promos),
              orElse: () => const SizedBox.shrink(),
            ),

            // ── Metode Pembayaran ──
            _sectionTitle("Metode Pembayaran", 18),
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

            if (!_isCash) ...[
              const SizedBox(height: 24),
              _sectionTitle("Nomor Referensi", 18),
              const SizedBox(height: 12),
              _whiteBox(
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

            const SizedBox(height: 24),

            // ── Ringkasan biaya ──
            _totalsCard(cartState),
            const SizedBox(height: 24),

            // ── Jumlah Bayar ──
            _sectionTitle("Jumlah Bayar", 18),
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
            const SizedBox(height: 40),

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

  // ── Baris cart ──
  Widget _cartRow(CartItem item) {
    final chips = <Widget>[
      ...item.freeToppings.map((t) => _toppingChip('${t.topping.name} ×${t.qty}', true)),
      ...item.extraToppings
          .map((t) => _toppingChip('${t.topping.name} ×${t.qty} (+${formatRupiah(t.lineTotal)})', false)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                          .updateQuantity(item.lineId, item.quantity - 1),
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
                          .updateQuantity(item.lineId, item.quantity + 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(formatRupiah(item.subtotal),
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: chips),
          ],
          Row(
            children: [
              _lineAction(Icons.tune, "Topping", () => _editLine(item)),
              if (item.hasToppings) ...[
                const SizedBox(width: 16),
                _lineAction(Icons.copy_all_outlined, "Duplikat & ubah", () => _duplicateAndEdit(item)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _toppingChip(String label, bool isFree) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isFree ? Colors.green : AppTheme.brandBlue).withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isFree ? Colors.green.shade700 : AppTheme.brandBlue)),
    );
  }

  // ── Section promo ──
  Widget _promoSection(ProductTransactionState cart, List<Promo> promos) {
    if (promos.isEmpty) return const SizedBox.shrink();

    final selected = cart.selectedPromo;
    final maxFree = selected?.maxFreeQty(cart.paidQty) ?? 0;
    final remaining = maxFree - cart.selectedFreeQty;

    // Produk unik di cart (untuk dipilih sebagai item gratis bonus).
    final products = <int, Product>{};
    for (final i in cart.items) {
      products[i.product.id] = i.product;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Promo", 18),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _promoChip("Tanpa promo", selected == null, () {
              ref.read(productTransactionProvider.notifier).selectPromo(null);
            }),
            ...promos.map((p) => _promoChip(
                  "${p.name} (B${p.buyQty}G${p.freeQty})",
                  selected?.id == p.id,
                  () => ref.read(productTransactionProvider.notifier).selectPromo(p),
                )),
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: 12),
          if (maxFree <= 0)
            _infoBox(
              "Belum memenuhi syarat promo. Item dibayar: ${cart.paidQty} "
              "(min. ${selected.buyQty} untuk ${selected.freeQty} item gratis).",
            )
          else ...[
            _infoBox("Pilih item gratis (bonus) — sisa kuota: $remaining dari $maxFree"),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                children: products.values.map((p) {
                  final matches = cart.promoFreeItems.where((f) => f.product.id == p.id);
                  final sel = matches.isEmpty ? null : matches.first;
                  return _promoFreeRow(p, sel, canAdd: remaining > 0);
                }).toList(),
              ),
            ),
          ],
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  /// Satu baris produk pada selektor item gratis (bonus).
  Widget _promoFreeRow(Product p, PromoFreeSelection? sel, {required bool canAdd}) {
    final chips = <Widget>[
      if (sel != null) ...[
        ...sel.freeToppings.map((t) => _toppingChip('${t.topping.name} ×${t.qty}', true)),
        ...sel.extraToppings
            .map((t) => _toppingChip('${t.topping.name} ×${t.qty} (+${formatRupiah(t.lineTotal)})', false)),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sel == null ? p.name : '${p.name} ×${sel.qty}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
              ),
              if (sel == null)
                TextButton.icon(
                  onPressed: canAdd ? () => _addOrEditPromoFree(p, null) : null,
                  icon: const Icon(Icons.card_giftcard, size: 16),
                  label: const Text("Gratiskan"),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.brandBlue),
                )
              else ...[
                IconButton(
                  onPressed: () => _addOrEditPromoFree(p, sel),
                  icon: const Icon(Icons.tune, size: 18, color: AppTheme.brandBlue),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: () =>
                      ref.read(productTransactionProvider.notifier).removePromoFreeItem(p.id),
                  icon: const Icon(Icons.close, size: 18, color: AppTheme.danger),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: chips),
          ],
        ],
      ),
    );
  }

  Future<void> _addOrEditPromoFree(Product p, PromoFreeSelection? existing) async {
    final result = await showToppingPicker(
      context,
      product: p,
      initialQty: existing?.qty ?? 1,
      initialFree: existing?.freeToppings ?? const [],
      initialExtra: existing?.extraToppings ?? const [],
    );
    if (result == null) return;
    ref.read(productTransactionProvider.notifier).setPromoFreeItem(
          p,
          qty: result.quantity,
          freeToppings: result.freeToppings,
          extraToppings: result.extraToppings,
        );
  }

  Widget _promoChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.brandBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.brandBlue : AppTheme.borderLight, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
      ),
    );
  }

  Widget _infoBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.brandBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
    );
  }

  Widget _totalsCard(ProductTransactionState cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        children: [
          _totalRow("Subtotal", formatRupiah(cart.subtotal)),
          if (cart.promoDiscount > 0) ...[
            const SizedBox(height: 8),
            _totalRow("Diskon Promo", "- ${formatRupiah(cart.promoDiscount)}", color: Colors.green),
          ],
          const Divider(height: 24, color: AppTheme.borderLight),
          _totalRow("Total", formatRupiah(cart.total), bold: true),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false, Color? color}) {
    final style = TextStyle(
      fontSize: bold ? 17 : 14,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      color: color ?? (bold ? AppTheme.textPrimary : AppTheme.textSecondary),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(value, style: style)],
    );
  }

  Widget _sectionTitle(String text, double size) {
    return Text(text,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: size, fontWeight: FontWeight.w700));
  }

  Widget _whiteBox({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: child,
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
  final VoidCallback? onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 18, color: onTap == null ? AppTheme.borderLight : AppTheme.brandBlue),
      ),
    );
  }
}
