import 'package:flutter_test/flutter_test.dart';

import 'package:pos_mobile/data/models/qris_payment_model.dart';
import 'package:pos_mobile/presentation/widgets/snap_payment_view.dart';

void main() {
  group('QrisCharge', () {
    test('mode midtrans_snap memakai halaman Snap', () {
      final charge = QrisCharge.fromJson({
        'payment_ref': 'ESC-5-20260916211051-A1B2',
        'status': 'pending',
        'gross_amount': 1000,
        'qr_string': '',
        'qr_url': '',
        'payment_url': 'https://app.midtrans.com/snap/v4/redirection/tok',
        'expires_at': '2026-09-16T21:25:51+07:00',
        'provider': 'midtrans_snap',
        'manual_confirm': false,
      });
      expect(charge.provider, QrisProvider.midtransSnap);
      expect(charge.usesPaymentPage, isTrue);
      expect(charge.paymentUrl, 'https://app.midtrans.com/snap/v4/redirection/tok');
    });

    test('mode midtrans & manual tetap menggambar QR sendiri', () {
      for (final json in [
        {'payment_ref': 'A', 'qr_string': '000201', 'payment_url': '', 'provider': 'midtrans'},
        // BE lama tidak mengirim payment_url sama sekali.
        {'payment_ref': 'B', 'qr_string': '000201', 'provider': 'manual'},
      ]) {
        final charge = QrisCharge.fromJson(json);
        expect(charge.usesPaymentPage, isFalse, reason: json['provider']);
        expect(charge.paymentUrl, isNull, reason: json['provider']);
      }
    });
  });

  test('WebView Snap hanya boleh berada di domain Midtrans', () {
    expect(isMidtransHost('https://app.midtrans.com/snap/v4/redirection/tok'), isTrue);
    expect(isMidtransHost('https://app.sandbox.midtrans.com/snap/v4/redirection/tok'), isTrue);
    expect(isMidtransHost('http://example.com/finish?order_id=1'), isFalse);
    // Nama domain yang sekadar mengandung "midtrans.com" tidak boleh lolos.
    expect(isMidtransHost('https://midtrans.com.evil.test/'), isFalse);
    expect(isMidtransHost('https://notmidtrans.com/'), isFalse);
    expect(isMidtransHost('not a url'), isFalse);
  });
}
