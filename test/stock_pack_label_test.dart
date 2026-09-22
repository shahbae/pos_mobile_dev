import 'package:flutter_test/flutter_test.dart';

import 'package:pos_mobile/data/models/stock_pack_model.dart';

// Stok gudang di form permintaan dan jumlah di surat jalan dibaca dalam
// kemasan ("2 Jerigen + 500 ml"), bukan satuan dasar saja.

StockPack _jerigen(double qty) =>
    StockPack.of(qty: qty, templateId: 1, name: 'Jerigen', baseQty: 5000);

void main() {
  test('kemasan utuh + sisa', () {
    expect(_jerigen(10500).label('ml'), '2 Jerigen + 500 ml');
  });

  test('pas kemasan tanpa sisa', () {
    expect(_jerigen(10000).label('ml'), '2 Jerigen');
  });

  test('belum sampai satu kemasan tampil satuan dasar', () {
    expect(_jerigen(2500).label('ml'), '2.500 ml');
  });

  test('ribuan pakai pemisah titik', () {
    expect(_jerigen(5000 * 1200.0 + 1250).label('ml'), '1.200 Jerigen + 1.250 ml');
  });

  test('stok minus tidak dipecah jadi kemasan', () {
    final p = _jerigen(-300);
    expect(p.whole, 0);
    expect(p.label('ml'), '-300 ml');
  });

  test('pack dari BE (string desimal) terbaca', () {
    final p = StockPack.tryFrom({
      'template_id': 4,
      'name': 'Kardus',
      'base_qty': '24',
      'whole': '3',
      'remainder': '0',
      'exact': '3',
    });
    expect(p?.label('pcs'), '3 Kardus');
    expect(StockPack.tryFrom(null), isNull);
  });
}
