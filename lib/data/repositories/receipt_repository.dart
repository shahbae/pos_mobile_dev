import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/receipt_model.dart';
import 'package:pos_mobile/data/services/api_services.dart';
import 'package:pos_mobile/data/services/api_provider.dart';

final receiptRepositoryProvider = Provider<ReceiptRepository>((ref) {
  final api = ref.watch(apiProvider);
  return ReceiptRepository(api);
});

class ReceiptRepository {
  final ApiService api;
  ReceiptRepository(this.api);

  /// Ambil data nota berdasarkan nomor invoice (untuk reprint).
  /// Endpoint: GET /product-transactions/{invoice_no}
  Future<Receipt> getReceipt(String invoiceNo) async {
    final res = await api.dio.get('/product-transactions/$invoiceNo');
    return Receipt.fromJson(res.data);
  }
}

/// Provider nota by invoice_no. Dipakai di halaman cetak nota.
final receiptProvider =
    FutureProvider.autoDispose.family<Receipt, String>((ref, invoiceNo) async {
  return ref.watch(receiptRepositoryProvider).getReceipt(invoiceNo);
});
