import 'dart:convert';

import 'package:pos_mobile/data/local/outbox_store.dart';
import 'package:pos_mobile/data/models/pos_catalog_model.dart';
import 'package:pos_mobile/data/models/receipt_model.dart';
import 'package:pos_mobile/presentation/providers/product_transaction_provider.dart';

/// Apa yang diketahui HP tentang sebuah penjualan offline di luar isi
/// keranjangnya: siapa, di shift mana, kapan, dan dari katalog yang mana.
class OfflineSaleContext {
  final int shiftId;
  final int cashierId;
  final String cashierName;
  final String deviceId;

  /// Katalog yang dipakai saat menjual. Harganya menjadi harga resmi penjualan
  /// ini, dan info tokonya menjadi kepala nota.
  final PosCatalog catalog;

  /// Jam kejadian, sudah dikoreksi selisih jam server.
  final DateTime occurredAt;

  const OfflineSaleContext({
    required this.shiftId,
    required this.cashierId,
    required this.cashierName,
    required this.deviceId,
    required this.catalog,
    required this.occurredAt,
  });
}

/// Nomor nota lokal: `OFF-<yyyymmdd>-<urut 4 angka>`.
String offlineClientRef(DateTime day, int seq) {
  final d = '${day.year.toString().padLeft(4, '0')}${day.month.toString().padLeft(2, '0')}'
      '${day.day.toString().padLeft(2, '0')}';
  return 'OFF-$d-${seq.toString().padLeft(4, '0')}';
}

/// Susun satu penjualan offline dari keranjang: isi permintaan untuk
/// `POST /product-transactions/offline` dan nota untuk pembeli.
///
/// Fungsi murni: angka yang sama selalu menghasilkan nota yang sama. Dipanggil
/// di dalam transaksi penyimpanan, setelah nomor nota dan antrean dipesan.
OutboxDraft buildOfflineSale({
  required ProductTransactionState cart,
  required OfflineSaleContext context,
  required OfflineNumbers numbers,
  required String idempotencyKey,
  required int paid,
  String? customerName,
}) {
  final clientRef = offlineClientRef(context.occurredAt, numbers.noteSeq);
  final lines = saleLinesOf(cart, withPrices: true);
  final total = cart.total.toInt();
  final name = (customerName == null || customerName.trim().isEmpty) ? null : customerName.trim();

  final payload = <String, dynamic>{
    'idempotency_key': idempotencyKey,
    'payment_method': 'CASH',
    'paid': paid,
    'discount': 0,
    'total': total,
    // Server membaca waktu dengan zona; jam lokal tanpa zona akan ditolak.
    'occurred_at': context.occurredAt.toUtc().toIso8601String(),
    'client_ref': clientRef,
    'queue_no': numbers.queueNo,
    'shift_id': context.shiftId,
    'cashier_id': context.cashierId,
    'device_id': context.deviceId,
    'catalog_version': context.catalog.version,
    'catalog_fetched_at': context.catalog.fetchedAt.toUtc().toIso8601String(),
    'items': lines.items.map((i) => i.toJson()).toList(),
    if (lines.promoFreeItems.isNotEmpty)
      'promo_free_items': lines.promoFreeItems.map((p) => p.toJson()).toList(),
    if (lines.plastics.isNotEmpty) 'plastics': lines.plastics.map((p) => p.toJson()).toList(),
    if (lines.sedotans.isNotEmpty) 'sedotans': lines.sedotans.map((s) => s.toJson()).toList(),
    if (name != null) 'customer_name': name,
  };

  final receipt = _receipt(
    cart: cart,
    context: context,
    clientRef: clientRef,
    queueNo: numbers.queueNo,
    total: total,
    paid: paid,
    customerName: name,
  );

  return OutboxDraft(
    clientRef: clientRef,
    payload: jsonEncode(payload),
    receipt: jsonEncode(receipt.toJson()),
  );
}

Receipt _receipt({
  required ProductTransactionState cart,
  required OfflineSaleContext context,
  required String clientRef,
  required int queueNo,
  required int total,
  required int paid,
  required String? customerName,
}) {
  final promo = cart.selectedPromo;
  final bonuses = promo == null ? const <PromoFreeSelection>[] : cart.promoFreeItems;

  // Waktu pembuatan pesanan ini sendiri: per gelas, dijumlahkan. Saat offline
  // antrean dapur tidak diketahui, jadi hanya ini yang bisa dijanjikan.
  var prepMinutes = 0;
  for (final i in cart.items) {
    final perUnit = i.variant?.effectivePrepFor(i.product.prepMinutes) ?? i.product.prepMinutes;
    prepMinutes += perUnit * i.quantity;
  }
  for (final b in bonuses) {
    final perUnit = b.variant?.effectivePrepFor(b.product.prepMinutes) ?? b.product.prepMinutes;
    prepMinutes += perUnit * b.qty;
  }
  final at = context.occurredAt;
  final readyAt = prepMinutes > 0
      ? DateTime(at.year, at.month, at.day, at.hour, at.minute).add(Duration(minutes: prepMinutes))
      : null;

  final store = context.catalog.store;
  return Receipt(
    invoiceNo: clientRef,
    createdAt: at,
    cashierName: context.cashierName,
    customerName: customerName,
    items: [
      for (final i in cart.items)
        ReceiptItem(
          name: i.product.name,
          variantName: i.variant?.name,
          qty: i.quantity,
          price: i.unitPrice,
          toppings: [
            // Jumlah topping di nota adalah total untuk baris itu, seperti di
            // struk server: per gelas × jumlah gelas.
            for (final t in i.freeToppings)
              ReceiptTopping(name: t.topping.name, qty: t.qty * i.quantity, price: 0),
            for (final t in i.extraToppings)
              ReceiptTopping(name: t.topping.name, qty: t.qty * i.quantity, price: t.topping.price),
          ],
        ),
      for (final b in bonuses)
        ReceiptItem(name: b.product.name, variantName: b.variant?.name, qty: b.qty, price: b.unitPrice),
    ],
    plastics: [for (final p in cart.plastics) ReceiptPlastic(name: p.plastic.name, qty: p.qty)],
    sedotans: [for (final s in cart.sedotans) ReceiptSedotan(name: s.sedotan.name, qty: s.qty)],
    subtotal: cart.subtotal,
    discount: 0,
    promoDiscount: cart.promoDiscount,
    promos: [
      for (final b in bonuses) ReceiptPromo(name: promo!.name, discount: b.discountValue),
    ],
    tax: 0,
    total: total,
    paid: paid,
    change: paid > total ? paid - total : 0,
    paymentMethod: 'cash',
    paymentRef: null,
    estimatedPrepMinutes: prepMinutes,
    queueNo: queueNo,
    estimatedReadyAt: readyAt,
    store: ReceiptStore(
      name: store.name,
      address: store.address,
      footerNote: store.footerNote,
      complaintNote: store.complaintNote,
    ),
  );
}
