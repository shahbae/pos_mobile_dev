import 'package:flutter_test/flutter_test.dart';

import 'package:pos_mobile/data/models/product_model.dart';
import 'package:pos_mobile/data/models/promo_model.dart';
import 'package:pos_mobile/data/models/sedotan_model.dart';
import 'package:pos_mobile/data/models/topping_model.dart';
import 'package:pos_mobile/data/repositories/product_transaction_repository.dart';
import 'package:pos_mobile/presentation/providers/product_transaction_provider.dart';

// Sedotan besar untuk gelas bertopping, kecil untuk tanpa topping. Aplikasi yang
// mengisi angkanya; backend mencatat apa adanya. Jadi kalau hitungan di sini
// salah, stok sedotan ikut salah tanpa ada yang menolak.

class _UnusedRepo implements ProductTransactionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final _original = Product(id: 1, name: 'Original', purchasePrice: '0', sellingPrice: '5000');
final _oreo = Topping(id: 1, name: 'Oreo', price: 2000);

final _besar = Sedotan(id: 2, name: 'Sedotan Besar', autoFor: SedotanAutoFor.withTopping);
final _kecil = Sedotan(id: 1, name: 'Sedotan kecil', autoFor: SedotanAutoFor.withoutTopping);
final _tutupCup = Sedotan(id: 3, name: 'Tutup Cup');

int _qty(ProductTransactionNotifier n, Sedotan s) =>
    n.state.sedotans.where((cs) => cs.sedotan.id == s.id).fold(0, (sum, cs) => sum + cs.qty);

ProductTransactionNotifier _notifier() {
  final n = ProductTransactionNotifier(_UnusedRepo());
  n.setSedotanMasters([_kecil, _besar, _tutupCup]);
  return n;
}

void main() {
  test('gelas bertopping ke sedotan besar, sisanya ke sedotan kecil', () {
    final n = _notifier();
    n.addToCart(_original);
    n.addToCart(_original); // baris polos qty 2
    n.addLineWithToppings(_original, quantity: 3, extraToppings: [CartTopping(topping: _oreo)]);

    expect(_qty(n, _besar), 3);
    expect(_qty(n, _kecil), 2);
    expect(_qty(n, _tutupCup), 0, reason: 'sedotan manual tak pernah diisi otomatis');
  });

  test('ikut berubah saat keranjang berubah', () {
    final n = _notifier();
    n.addLineWithToppings(_original, freeToppings: [CartTopping(topping: _oreo)]);
    final lineId = n.state.items.single.lineId;
    expect(_qty(n, _besar), 1, reason: 'topping gratis juga dihitung bertopping');

    n.updateQuantity(lineId, 4);
    expect(_qty(n, _besar), 4);

    n.updateLineToppings(lineId, freeToppings: const [], extraToppings: const []);
    expect(_qty(n, _besar), 0);
    expect(_qty(n, _kecil), 4);

    n.removeLine(lineId);
    expect(n.state.sedotans, isEmpty);
  });

  test('gelas tumbler tetap dapat sedotan', () {
    final n = _notifier();
    n.addToCart(_original);
    n.addToCart(_original);
    n.setTumblerQty(n.state.items.single.lineId, 2);
    expect(_qty(n, _kecil), 2);
  });

  test('bonus promo dihitung sebagai gelas tanpa topping', () {
    final n = _notifier();
    n.addLineWithToppings(_original, quantity: 2, extraToppings: [CartTopping(topping: _oreo)]);
    n.selectPromo(Promo(id: 1, name: 'Beli 2 gratis 1', buyQty: 2, freeQty: 1));
    n.setPromoFreeItem(_original, qty: 1);

    expect(_qty(n, _besar), 2);
    expect(_qty(n, _kecil), 1);

    n.selectPromo(null);
    expect(_qty(n, _kecil), 0);
  });

  test('angka yang diubah kasir tidak ditimpa lagi, termasuk nol', () {
    final n = _notifier();
    n.addToCart(_original);
    n.addToCart(_original);
    expect(_qty(n, _kecil), 2);

    n.setSedotan(_kecil, qty: 0); // pembeli tak mau sedotan
    n.addToCart(_original);
    expect(_qty(n, _kecil), 0);

    n.addLineWithToppings(_original, extraToppings: [CartTopping(topping: _oreo)]);
    expect(_qty(n, _besar), 1, reason: 'sedotan lain tetap otomatis');

    n.clearCart();
    n.addToCart(_original);
    expect(_qty(n, _kecil), 1, reason: 'transaksi baru mulai otomatis lagi');
  });

  test('master belum termuat: tidak ada yang diisi', () {
    final n = ProductTransactionNotifier(_UnusedRepo());
    n.addToCart(_original);
    expect(n.state.sedotans, isEmpty);

    n.setSedotanMasters([_kecil, _besar]);
    expect(_qty(n, _kecil), 1, reason: 'terisi begitu master datang');
  });

  test('BE lama tanpa auto_for dianggap manual', () {
    final s = Sedotan.fromJson({'id': 9, 'name': 'Sedotan', 'is_active': true});
    expect(s.autoFor, SedotanAutoFor.none);
  });
}
