import 'package:flutter_test/flutter_test.dart';

import 'package:pos_mobile/data/models/product_model.dart';
import 'package:pos_mobile/data/models/product_transaction_model.dart';
import 'package:pos_mobile/data/models/qris_payment_model.dart';
import 'package:pos_mobile/data/repositories/product_transaction_repository.dart';
import 'package:pos_mobile/presentation/providers/product_transaction_provider.dart';

// Server menolak idempotency key kembar, jadi key inilah yang menentukan apakah
// tekan "Bayar" kedua mencatat penjualan baru atau mengembalikan yang sudah
// tercatat. Key yang berganti di saat yang salah = penjualan dobel; key yang
// bertahan di saat yang salah = pesanan pembeli berikutnya tidak tercatat.

const _timeout = TransactionSubmitException('timeout', rejected: false);
const _ditolak = TransactionSubmitException('stok habis', rejected: true);

/// Repo palsu: mencatat key tiap permintaan dan menjawab sesuai antrean
/// [answers] — sebuah galat dilempar, selain itu dianggap berhasil.
class _FakeRepo implements ProductTransactionRepository {
  final List<String?> keys = [];
  final List<Object?> answers = [];

  void _answer(ProductTransactionRequest request) {
    keys.add(request.idempotencyKey);
    final next = answers.isEmpty ? null : answers.removeAt(0);
    if (next != null) throw next;
  }

  @override
  Future<ProductTransactionResponse> createTransaction(ProductTransactionRequest request) async {
    _answer(request);
    return ProductTransactionResponse(invoiceNumber: 'INV-1', saleId: 1, success: true);
  }

  @override
  Future<QrisChargeResult> createQrisTransaction(ProductTransactionRequest request) async {
    _answer(request);
    return const QrisChargePending(
      QrisCharge(paymentRef: 'ESC-1', status: 'pending', grossAmount: 5000, qrString: 'x'),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final _original = Product(id: 1, name: 'Original', purchasePrice: '0', sellingPrice: '5000');
final _gratis = Product(id: 2, name: 'Air Putih', purchasePrice: '0', sellingPrice: '0');

(ProductTransactionNotifier, _FakeRepo) _kasir({Product? produk}) {
  final repo = _FakeRepo();
  final n = ProductTransactionNotifier(repo)..addToCart(produk ?? _original);
  return (n, repo);
}

Future<void> _tunai(ProductTransactionNotifier n) =>
    n.submitTransaction(paymentMethod: 'CASH', paid: 5000);

void main() {
  test('jawaban hilang lalu bayar lagi: key yang sama', () async {
    final (n, repo) = _kasir();
    repo.answers.addAll([_timeout, _timeout]);

    await _tunai(n);
    await _tunai(n);
    await _tunai(n);

    expect(repo.keys.toSet(), hasLength(1));
    expect(n.state.lastResponse?.invoiceNumber, 'INV-1');
  });

  test('galat yang bukan dari server juga dianggap belum pasti', () async {
    final (n, repo) = _kasir();
    repo.answers.add(const FormatException('response tak terbaca'));

    await _tunai(n);
    await _tunai(n);

    expect(repo.keys[1], repo.keys[0]);
  });

  test('ditolak server: percobaan berikutnya transaksi baru', () async {
    final (n, repo) = _kasir();
    repo.answers.add(_ditolak);

    await _tunai(n);
    await _tunai(n);

    expect(repo.keys[1], isNot(repo.keys[0]));
  });

  test('berhasil: pesanan berikutnya yang isinya sama tetap transaksi baru', () async {
    final (n, repo) = _kasir();

    await _tunai(n);
    n.addToCart(_original);
    await _tunai(n);

    expect(repo.keys[1], isNot(repo.keys[0]));
  });

  test('isi keranjang berubah: key baru', () async {
    final (n, repo) = _kasir();
    repo.answers.add(_timeout);

    await _tunai(n);
    n.addToCart(_original); // qty 1 → 2
    await _tunai(n);

    expect(repo.keys[1], isNot(repo.keys[0]));
  });

  test('ganti nominal bayar atau nama pembeli: key tetap', () async {
    final (n, repo) = _kasir();
    repo.answers.add(_timeout);

    await n.submitTransaction(paymentMethod: 'CASH', paid: 5000);
    await n.submitTransaction(paymentMethod: 'CASH', paid: 10000, customerName: 'Budi');

    expect(repo.keys[1], repo.keys[0]);
  });

  test('keranjang dikosongkan: key dilepas', () async {
    final (n, repo) = _kasir();
    repo.answers.add(_timeout);

    await _tunai(n);
    n.clearCart();
    n.addToCart(_original);
    await _tunai(n);

    expect(repo.keys[1], isNot(repo.keys[0]));
  });

  group('pindah metode bayar', () {
    test('QRIS tanpa jawaban lalu QRIS lagi: key yang sama, QR yang sama', () async {
      final (n, repo) = _kasir();
      repo.answers.add(_timeout);

      await n.chargeQris();
      await n.chargeQris();

      expect(repo.keys[1], repo.keys[0]);
    });

    test('QR sudah tampil: percobaan berikutnya transaksi baru', () async {
      final (n, repo) = _kasir();

      await n.chargeQris(); // QR tampil, lalu dibatalkan / kedaluwarsa
      await n.chargeQris();

      expect(repo.keys[1], isNot(repo.keys[0]));
    });

    // Yang mungkin tertinggal di server hanya QR yang belum dibayar, dan QR
    // tidak bisa dilunasi dengan tunai.
    test('QRIS tanpa jawaban lalu tunai: key baru', () async {
      final (n, repo) = _kasir();
      repo.answers.add(_timeout);

      await n.chargeQris();
      await _tunai(n);

      expect(repo.keys[1], isNot(repo.keys[0]));
    });

    // Tunai yang jawabannya hilang bisa saja sudah tercatat LUNAS. Key baru di
    // sini berarti dua penjualan untuk satu pesanan.
    test('tunai tanpa jawaban lalu QRIS: key yang sama', () async {
      final (n, repo) = _kasir();
      repo.answers.add(_timeout);

      await _tunai(n);
      await n.chargeQris();

      expect(repo.keys[1], repo.keys[0]);
    });

    test('tunai, QRIS, tunai tanpa jawaban sama sekali: key tetap satu', () async {
      final (n, repo) = _kasir();
      repo.answers.addAll([_timeout, _timeout]);

      await _tunai(n);
      await n.chargeQris();
      await _tunai(n);

      expect(repo.keys.toSet(), hasLength(1));
    });

    // Server mencatat QRIS Rp0 langsung lunas tanpa QR, jadi perlakuannya
    // seperti tunai.
    test('QRIS Rp0 tanpa jawaban lalu tunai: key yang sama', () async {
      final (n, repo) = _kasir(produk: _gratis);
      repo.answers.add(_timeout);

      await n.chargeQris();
      await n.submitTransaction(paymentMethod: 'CASH', paid: 0);

      expect(repo.keys[1], repo.keys[0]);
    });
  });
}
