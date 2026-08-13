import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_mobile/data/models/product_variant_model.dart';
import 'package:pos_mobile/data/models/promo_model.dart';
import 'package:pos_mobile/data/models/plastic_model.dart';
import 'package:pos_mobile/data/models/sedotan_model.dart';
import 'package:pos_mobile/data/models/product_transaction_model.dart';
import 'package:pos_mobile/data/models/qris_payment_model.dart';
import 'package:pos_mobile/presentation/pages/product_transactions/qris_payment_page.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/presentation/providers/product_pagination_provider.dart';
import 'package:pos_mobile/presentation/providers/product_provider.dart';
import 'package:pos_mobile/presentation/providers/product_transaction_provider.dart';
import 'package:pos_mobile/presentation/providers/plastic_provider.dart';
import 'package:pos_mobile/presentation/providers/sedotan_provider.dart';
import 'package:pos_mobile/presentation/providers/promo_provider.dart';
import 'package:pos_mobile/presentation/providers/transaction_refresh.dart';
import 'package:pos_mobile/presentation/pages/product_transactions/transaction_success_page.dart';
import 'package:pos_mobile/presentation/widgets/free_item_picker_sheet.dart';
import 'package:pos_mobile/presentation/widgets/topping_picker_sheet.dart';
import 'package:pos_mobile/presentation/widgets/variant_picker_sheet.dart';
import 'package:pos_mobile/utils/currency.dart';
import 'package:pos_mobile/utils/xl_promo.dart';
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
  _PayMethod('QRIS', 'QRIS', Icons.qr_code_2_outlined),
  // Metode lain dinonaktifkan sementara — aktifkan kembali bila BE & alur siap.
  // _PayMethod('TRANSFER', 'Transfer', Icons.account_balance_outlined),
  // _PayMethod('DEBIT', 'Debit', Icons.credit_card_outlined),
  // _PayMethod('CREDIT', 'Kredit', Icons.credit_score_outlined),
  // _PayMethod('EWALLET', 'E-Wallet', Icons.account_balance_wallet_outlined),
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
  final FocusNode _paidFocus = FocusNode();
  String _paymentMethod = 'CASH';
  num _lastTotal = 0;

  /// Kasir sudah menyentuh field "Jumlah Bayar"? Kalau sudah, isinya tidak
  /// pernah ditimpa otomatis lagi — termasuk saat sengaja dikosongkan.
  bool _paidTouched = false;

  bool get _isCash => _paymentMethod == 'CASH';
  bool get _isQris => _paymentMethod == 'QRIS';

  @override
  void initState() {
    super.initState();
    _lastTotal = ref.read(productTransactionProvider).total;
    _paidAmountController.text = NumberFormat.decimalPattern('id_ID').format(_lastTotal);
    // Fokus ke field = langsung blok semua teks, jadi mengetik nominal baru
    // tidak perlu menghapus angka lama satu per satu.
    _paidFocus.addListener(() {
      if (!_paidFocus.hasFocus) return;
      _paidAmountController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _paidAmountController.text.length,
      );
    });
  }

  @override
  void dispose() {
    _paidAmountController.dispose();
    _customerNameController.dispose();
    _paymentRefController.dispose();
    _paidFocus.dispose();
    super.dispose();
  }

  /// Ikutkan "Jumlah Bayar" ke total belanja selama kasir belum mengubahnya
  /// sendiri. Field yang sudah disentuh dibiarkan apa adanya.
  void _syncPaidIfUntouched(num total) {
    if (total == _lastTotal) return;
    _lastTotal = total;
    if (_paidTouched) return;
    _paidAmountController.text = NumberFormat.decimalPattern('id_ID').format(total);
  }

  Future<void> _submit(num total) async {
    // QRIS pakai alur asinkron (buat QR → poll → lunas). Nominal = total otomatis.
    if (_isQris) {
      await _submitQris();
      return;
    }

    final rawPaid = _paidAmountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final paidValue = int.tryParse(rawPaid) ?? 0;

    if (rawPaid.isEmpty) {
      _toast("Jumlah bayar belum diisi", Colors.orange);
      return;
    }
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
      _goToSuccess(newState.lastResponse!);
    } else if (newState.error != null) {
      _toast("Gagal: ${newState.error}", Colors.red);
      // Stok bisa berubah sejak katalog dimuat (mis. ditolak karena bahan habis).
      // Muat ulang daftar produk agar penanda ketersediaan ikut ter-refresh.
      if (newState.error!.toLowerCase().contains('habis')) {
        ref.read(productPaginationProvider.notifier).loadAll();
      }
    }
  }

  /// Alur QRIS dinamis: charge → (QR page + polling) → lunas cetak struk.
  Future<void> _submitQris() async {
    final notifier = ref.read(productTransactionProvider.notifier);
    final customerName = _customerNameController.text.trim().isEmpty
        ? null
        : _customerNameController.text.trim();

    final result = await notifier.chargeQris(customerName: customerName);
    if (!mounted) return;

    if (result == null) {
      final err = ref.read(productTransactionProvider).error;
      _toast("Gagal: ${err ?? 'tidak diketahui'}", Colors.red);
      if ((err ?? '').toLowerCase().contains('habis')) {
        ref.read(productPaginationProvider.notifier).loadAll();
      }
      return;
    }

    // Response B — Midtrans belum aktif, transaksi langsung lunas.
    if (result is QrisChargeCompleted) {
      notifier.clearCart();
      _goToSuccess(result.response);
      return;
    }

    // Response A — tampilkan QR, tunggu pembayaran.
    if (result is QrisChargePending) {
      final invoiceNo = await Navigator.push<String?>(
        context,
        MaterialPageRoute(builder: (_) => QrisPaymentPage(charge: result.charge)),
      );
      if (!mounted) return;
      if (invoiceNo != null) {
        // Lunas → reset keranjang & tampilkan struk (auto-print bila diset).
        notifier.clearCart();
        _goToSuccess(ProductTransactionResponse(
          invoiceNumber: invoiceNo,
          saleId: 0,
          success: true,
        ));
      }
      // Dibatalkan / kedaluwarsa → tetap di checkout, keranjang utuh (bisa ulangi).
    }
  }

  /// Satu-satunya pintu ke halaman sukses — sekaligus tempat membuang cache
  /// data yang sudah basi begitu transaksi tercatat (katalog, dashboard,
  /// shift, riwayat, stok plastik/sedotan).
  void _goToSuccess(ProductTransactionResponse response) {
    invalidateAfterTransaction(ref);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => TransactionSuccessPage(response: response)),
    );
  }

  void _toast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  int _paidValue() => int.tryParse(_paidAmountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  void _setPaid(num amount) {
    _paidAmountController.text = NumberFormat.decimalPattern('id_ID').format(amount);
    setState(() => _paidTouched = true);
  }

  void _clearPaid() {
    _paidAmountController.clear();
    setState(() => _paidTouched = true);
  }

  /// Tombol nominal cepat untuk tunai.
  Widget _quickCash(num total) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _cashChip("Uang Pas", () => _setPaid(total)),
        for (final amt in const [50000, 100000, 150000, 200000])
          _cashChip(formatRupiah(amt), () => _setPaid(amt)),
      ],
    );
  }

  Widget _cashChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.brandBlue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.brandBlue.withOpacity(0.25)),
        ),
        child: Text(label,
            style: const TextStyle(color: AppTheme.brandBlue, fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }

  /// Kartu kembalian / kurang, dihitung real-time. Untuk metode non-tunai
  /// kelebihannya bukan "kembalian", jadi labelnya dibedakan.
  Widget _changeCard(num total) {
    final paid = _paidValue();
    final change = paid - total;
    final isEnough = change >= 0;
    final color = isEnough ? Colors.green : Colors.orange;
    final enoughLabel = _isCash ? "Kembalian" : "Lebih Bayar";
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(isEnough ? enoughLabel : "Kurang",
              style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
          Text(formatRupiah(change.abs()),
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Future<void> _editLine(CartItem item) async {
    final result = await showToppingPicker(
      context,
      product: item.product,
      variant: item.variant,
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
      variant: item.variant,
      initialQty: 1,
      initialFree: item.freeToppings,
      initialExtra: item.extraToppings,
    );
    if (result == null) return;
    ref.read(productTransactionProvider.notifier).addLineWithToppings(
          item.product,
          variant: item.variant,
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Atas Nama ──
            _sectionTitle("Atas Nama (Opsional)", 16),
            const SizedBox(height: 12),
            _whiteBox(
              child: TextField(
                controller: _customerNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: "Nama pelanggan",
                  prefixIcon: Icon(Icons.person_outline, color: AppTheme.brandBlue),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
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

            // ── Kemasan (Plastik) ──
            _plasticSection(cartState),

            // ── Sedotan ──
            _sedotanSection(cartState),

            // ── Promo ──
            promosAsync.when(
              data: (promos) => _promoSection(cartState, promos),
              // Sama seperti kemasan: kalau seksi ini diam-diam hilang saat
              // gagal dimuat, kasir mengira hari ini memang tidak ada promo.
              loading: () => _sectionPlaceholder("Promo"),
              error: (_, __) => _sectionError(
                "Promo",
                () => ref.invalidate(activePromosProvider),
              ),
            ),

            // ── Metode Pembayaran ──
            _sectionTitle("Metode Pembayaran", 18),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.8,
              children: _payMethods
                  .map((m) => _PaymentMethodCard(
                        label: m.label,
                        icon: m.icon,
                        isSelected: _paymentMethod == m.value,
                        onTap: () => setState(() {
                          _paymentMethod = m.value;
                          // Reset jumlah bayar ke total saat ganti metode —
                          // sekaligus mengembalikan sinkronisasi otomatis.
                          _paidTouched = false;
                          _paidAmountController.text =
                              NumberFormat.decimalPattern('id_ID').format(cartState.total);
                        }),
                      ))
                  .toList(),
            ),

            if (!_isCash && !_isQris) ...[
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
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── Ringkasan biaya ──
            _totalsCard(cartState),
            if (!_isQris) ...[
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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _paidAmountController,
                      focusNode: _paidFocus,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      inputFormatters: [CurrencyInputFormatter()],
                      onChanged: (_) => setState(() => _paidTouched = true),
                      style: const TextStyle(
                        color: AppTheme.brandBlue,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: const InputDecoration(
                        hintText: "0",
                        hintStyle: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
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
                  if (_paidAmountController.text.isNotEmpty)
                    IconButton(
                      tooltip: "Bersihkan",
                      icon: const Icon(Icons.backspace_outlined, size: 20),
                      color: AppTheme.textSecondary,
                      onPressed: _clearPaid,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_isCash) ...[
              _quickCash(cartState.total),
              const SizedBox(height: 12),
            ],
            _changeCard(cartState.total),
            ],
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
                    : Text(
                        _isQris
                            ? "Buat QR ${formatRupiah(cartState.total)}"
                            : "Konfirmasi & Bayar ${formatRupiah(cartState.total)}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 40),
          ],
            ),
          ),
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
                    Text(item.displayName,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(formatRupiah(item.unitPrice),
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

  // ── Section kemasan (plastik) ──
  Widget _plasticSection(ProductTransactionState cart) {
    final plasticsAsync = ref.watch(plasticListProvider);
    return plasticsAsync.when(
      data: (plastics) {
        if (plastics.isEmpty) return const SizedBox.shrink();
        // qty terpilih per plastic_id
        final selected = {for (final cp in cart.plastics) cp.plastic.id: cp.qty};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle("Kemasan (Plastik)", 18),
            const SizedBox(height: 12),
            _infoBox("Gratis — tidak menambah total. Pilih kemasan yang dipakai untuk pesanan ini."),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < plastics.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: AppTheme.borderLight),
                    _plasticRow(plastics[i], selected[plastics[i].id] ?? 0),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
      // Jangan diam-diam menghilang: kalau seksi ini lenyap saat data belum
      // siap / gagal dimuat, kasir mengira transaksi ini memang tanpa kemasan
      // dan pemakaian plastik tidak tercatat.
      loading: () => _sectionPlaceholder("Kemasan (Plastik)"),
      error: (_, __) => _sectionError(
        "Kemasan (Plastik)",
        () => ref.invalidate(plasticListProvider),
      ),
    );
  }

  /// Rangka seksi saat daftar master masih dimuat.
  Widget _sectionPlaceholder(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title, 18),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Seksi gagal dimuat — tetap terlihat supaya kasir sadar ada yang belum siap.
  Widget _sectionError(String title, VoidCallback onRetry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title, 18),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  "Gagal memuat daftar.",
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text("Coba lagi",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _plasticRow(Plastic plastic, int qty) {
    final notifier = ref.read(productTransactionProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plastic.name,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                if (plastic.unit.isNotEmpty)
                  Text(plastic.unit,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
                  onTap: qty > 0 ? () => notifier.setPlastic(plastic, qty: qty - 1) : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text("$qty",
                      style: TextStyle(
                          color: qty > 0 ? AppTheme.brandBlue : AppTheme.textSecondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                ),
                _QtyButton(
                  icon: Icons.add,
                  onTap: () => notifier.setPlastic(plastic, qty: qty + 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section sedotan ──
  Widget _sedotanSection(ProductTransactionState cart) {
    final sedotansAsync = ref.watch(sedotanListProvider);
    return sedotansAsync.when(
      data: (sedotans) {
        if (sedotans.isEmpty) return const SizedBox.shrink();
        // qty terpilih per sedotan_id
        final selected = {for (final cs in cart.sedotans) cs.sedotan.id: cs.qty};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle("Sedotan", 18),
            const SizedBox(height: 12),
            _infoBox("Gratis — tidak menambah total. Pilih sedotan yang dipakai untuk pesanan ini."),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < sedotans.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: AppTheme.borderLight),
                    _sedotanRow(sedotans[i], selected[sedotans[i].id] ?? 0),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
      loading: () => _sectionPlaceholder("Sedotan"),
      error: (_, __) => _sectionError(
        "Sedotan",
        () => ref.invalidate(sedotanListProvider),
      ),
    );
  }

  Widget _sedotanRow(Sedotan sedotan, int qty) {
    final notifier = ref.read(productTransactionProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sedotan.name,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                if (sedotan.unit.isNotEmpty)
                  Text(sedotan.unit,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
                  onTap: qty > 0 ? () => notifier.setSedotan(sedotan, qty: qty - 1) : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text("$qty",
                      style: TextStyle(
                          color: qty > 0 ? AppTheme.brandBlue : AppTheme.textSecondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                ),
                _QtyButton(
                  icon: Icons.add,
                  onTap: () => notifier.setSedotan(sedotan, qty: qty + 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section promo ──
  Widget _promoSection(ProductTransactionState cart, List<Promo> promos) {
    if (promos.isEmpty) return const SizedBox.shrink();

    final selected = cart.selectedPromo;
    final maxFree = selected?.maxFreeQty(cart.paidQty) ?? 0;
    final remaining = maxFree - cart.selectedFreeQty;

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
            if (cart.promoFreeItems.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  children: cart.promoFreeItems
                      .map((sel) => _promoFreeRow(sel, canAdd: remaining > 0))
                      .toList(),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: remaining > 0 ? _pickFreeItem : null,
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Tambah item gratis"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.brandBlue,
                  side: const BorderSide(color: AppTheme.brandBlue),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  /// Satu baris item gratis (bonus) yang sudah dipilih.
  Widget _promoFreeRow(PromoFreeSelection sel, {required bool canAdd}) {
    final notifier = ref.read(productTransactionProvider.notifier);
    final qty = sel.qty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${sel.displayName} — gratis',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
          ),
          _QtyButton(
            icon: Icons.remove,
            onTap: () =>
                notifier.setPromoFreeItem(sel.product, variant: sel.variant, qty: qty - 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text("$qty",
                style: const TextStyle(
                    color: AppTheme.brandBlue, fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          _QtyButton(
            icon: Icons.add,
            onTap: canAdd
                ? () => notifier.setPromoFreeItem(sel.product, variant: sel.variant, qty: qty + 1)
                : null,
          ),
          IconButton(
            onPressed: () => notifier.removePromoFreeItem(sel.key),
            icon: const Icon(Icons.close, size: 18, color: AppTheme.danger),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  /// Pilih bonus gratis dari ISI KERANJANG — produk di luar keranjang tidak
  /// boleh, dan yang boleh hanya produk dengan harga terendah di keranjang
  /// (aturan BE). Variannya tetap kasir yang pilih, jadi boleh menggratiskan
  /// varian lain dari produk yang sama selama masih XL dan ≤ harga terendah.
  Future<void> _pickFreeItem() async {
    final items = ref.read(productTransactionProvider).items;
    if (items.isEmpty) {
      _toast("Tambahkan item ke keranjang dulu.", Colors.orange);
      return;
    }
    // Promo item gratis hanya berlaku bila SEMUA item di keranjang berukuran XL
    // (deteksi dari nama produk atau nama varian).
    final allXL =
        items.every((i) => nameHasXL(i.product.name) || nameHasXL(i.variant?.name));
    if (!allXL) {
      _toast("Item gratis hanya untuk transaksi yang semua itemnya ukuran XL.",
          Colors.orange);
      return;
    }
    // Harga dasar item termurah di keranjang (harga variant/produk, tanpa topping).
    final cheapest =
        items.map((i) => i.unitPrice).reduce((a, b) => a < b ? a : b);

    // Yang boleh digratiskan hanya baris keranjang yang kategorinya `freeable`
    // DAN harganya sama dengan item termurah tadi — sama seperti yang divalidasi
    // BE (ErrPOSFreeItemNotCheapest + kategori freeable).
    final eligible = items
        .where((i) => i.product.categoryFreeable && i.unitPrice <= cheapest)
        .toList();
    if (eligible.isEmpty) {
      _toast("Item termurah di keranjang tidak bisa digratiskan.", Colors.orange);
      return;
    }

    final product = await showFreeItemPicker(context, items: eligible);
    if (product == null || !mounted) return;

    // Varian bonus tidak harus sama dengan yang dipesan — mis. pesan "XL Normal",
    // bonusnya "XL Less sugar". Yang wajib: tetap XL dan ≤ harga terendah.
    ProductVariant? variant;
    if (product.hasVariants) {
      List<ProductVariant> variants = const [];
      try {
        variants = await ref.read(productVariantsProvider(product.id).future);
      } catch (_) {
        variants = const [];
      }
      if (!mounted) return;
      variants = variants
          .where((v) => nameHasXL(v.name) && v.sellingPriceNum <= cheapest)
          .toList();
      if (variants.isEmpty) {
        _toast("Tidak ada varian XL yang memenuhi batas harga item gratis.", Colors.orange);
        return;
      }
      variant = await showVariantPicker(
        context,
        product: product,
        variants: variants,
        maxPrice: cheapest,
      );
      if (variant == null || !mounted) return; // dibatalkan
    }

    // Tambah 1 bonus untuk produk+varian ini (akumulasi bila sudah ada).
    final key = '${product.id}_${variant?.id ?? 0}';
    final existing = ref.read(productTransactionProvider).promoFreeItems.where((p) => p.key == key);
    final currentQty = existing.isEmpty ? 0 : existing.first.qty;
    ref
        .read(productTransactionProvider.notifier)
        .setPromoFreeItem(product, variant: variant, qty: currentQty + 1);
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.brandBlue : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.brandBlue : AppTheme.borderLight,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.brandBlue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : AppTheme.textSecondary, size: 18),
            const SizedBox(width: 8),
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
