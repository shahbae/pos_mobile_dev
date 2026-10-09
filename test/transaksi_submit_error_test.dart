import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_mobile/data/models/product_transaction_model.dart';
import 'package:pos_mobile/data/models/qris_payment_model.dart';
import 'package:pos_mobile/data/repositories/product_transaction_repository.dart';
import 'package:pos_mobile/data/services/api_services.dart';

// Notifier memutuskan dari `rejected` apakah idempotency key boleh diganti.
// Salah memetakan di sini = key berganti padahal transaksinya mungkin sudah
// tercatat, dan tekan "Bayar" berikutnya mencatat penjualan kedua.

/// Menjawab setiap permintaan dengan [status] + [body], atau tanpa jawaban
/// sama sekali (timeout) bila [status] null.
class _FakeAdapter implements HttpClientAdapter {
  int? status;
  Object? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (status == null) {
      throw DioException.connectionTimeout(
        timeout: const Duration(seconds: 15),
        requestOptions: options,
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status!,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final _request = ProductTransactionRequest(
  items: [TransactionItem(productId: 1, quantity: 1)],
  paymentMethod: 'CASH',
  paid: 5000,
  idempotencyKey: 'kunci-uji',
);

const _struk = {
  'success': true,
  'data': {'invoice_no': 'INV-20261010-0001', 'payment_method': 'cash', 'total': 5000},
};

const _qrMenunggu = {
  'success': true,
  'data': {
    'payment_ref': 'ESC-1-X',
    'status': 'pending',
    'gross_amount': 5000,
    'qr_string': '000201',
    'provider': 'manual',
    'manual_confirm': true,
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAdapter adapter;
  late ProductTransactionRepository repo;

  setUpAll(() async {
    await dotenv.load(
      fileName: '.env',
      isOptional: true,
      mergeWith: {'API_BASE_URL': 'http://localhost'},
    );
    // Interceptor membaca token dari secure storage; di sini cukup "tidak ada".
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
  });

  setUp(() {
    adapter = _FakeAdapter();
    final api = ApiService()..dio.httpClientAdapter = adapter;
    repo = ProductTransactionRepository(api);
  });

  Future<TransactionSubmitException> gagal(Future<Object?> Function() submit) async {
    try {
      await submit();
    } on TransactionSubmitException catch (e) {
      return e;
    }
    fail('seharusnya melempar TransactionSubmitException');
  }

  group('rejected', () {
    test('422: ditolak, pesan server diteruskan', () async {
      adapter
        ..status = 422
        ..body = {'success': false, 'message': 'Stok Susu UHT tinggal 0.2 L, butuh 0.5 L'};

      final e = await gagal(() => repo.createTransaction(_request));

      expect(e.rejected, isTrue);
      expect(e.toString(), 'Stok Susu UHT tinggal 0.2 L, butuh 0.5 L');
    });

    test('409 (QR lama sudah mati): ditolak, jadi key boleh diganti', () async {
      adapter
        ..status = 409
        ..body = {'success': false, 'message': 'QR pesanan ini sudah dibatalkan.'};

      final e = await gagal(() => repo.createQrisTransaction(_request));

      expect(e.rejected, isTrue);
    });

    test('5xx: belum pasti', () async {
      for (final status in [500, 502, 503]) {
        adapter
          ..status = status
          ..body = {'success': false, 'message': 'galat'};

        final e = await gagal(() => repo.createTransaction(_request));

        expect(e.rejected, isFalse, reason: 'status $status');
      }
    });

    test('tanpa jawaban (timeout): belum pasti', () async {
      adapter.status = null;

      expect((await gagal(() => repo.createTransaction(_request))).rejected, isFalse);
      expect((await gagal(() => repo.createQrisTransaction(_request))).rejected, isFalse);
    });
  });

  group('bentuk balasan', () {
    test('tunai dibalas struk: metode bayar yang tercatat ikut terbaca', () async {
      adapter
        ..status = 201
        ..body = _struk;

      final res = await repo.createTransaction(_request);

      expect(res.invoiceNumber, 'INV-20261010-0001');
      expect(res.paymentMethod, 'cash');
    });

    // Balasan ulang untuk key yang ternyata milik QR yang masih menunggu. Tidak
    // boleh terbaca sebagai transaksi berhasil dengan nomor invoice kosong.
    test('tunai dibalas QR yang masih menunggu: galat, bukan berhasil', () async {
      adapter
        ..status = 201
        ..body = _qrMenunggu;

      final e = await gagal(() => repo.createTransaction(_request));

      expect(e.rejected, isFalse);
      expect(e.toString(), contains('QRIS'));
    });

    test('QRIS dibalas QR: tampilkan QR', () async {
      adapter
        ..status = 201
        ..body = _qrMenunggu;

      final res = await repo.createQrisTransaction(_request);

      expect(res, isA<QrisChargePending>());
      expect((res as QrisChargePending).charge.paymentRef, 'ESC-1-X');
    });

    // Percobaan tunai sebelumnya ternyata sudah tercatat lunas.
    test('QRIS dibalas struk tunai: selesai, dengan metode yang tercatat', () async {
      adapter
        ..status = 201
        ..body = _struk;

      final res = await repo.createQrisTransaction(_request);

      expect(res, isA<QrisChargeCompleted>());
      expect((res as QrisChargeCompleted).response.paymentMethod, 'cash');
    });
  });
}
