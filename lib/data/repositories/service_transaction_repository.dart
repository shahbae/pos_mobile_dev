import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pos_mobile/data/models/service_transaction_model.dart';
import 'package:pos_mobile/data/services/api_services.dart';

class ServiceTransactionRepository {
  final ApiService api;

  ServiceTransactionRepository(this.api);

  Future<ServiceTransactionResponse> checkout(ServiceTransactionRequest req) async {
    try {
      final payload = req.toJson();
      debugPrint('[ServiceTransaction] Checkout Payload: $payload');
      
      final res = await api.dio.post('/service-transactions', data: payload);
      
      debugPrint('[ServiceTransaction] Checkout Response code: ${res.statusCode}');
      debugPrint('[ServiceTransaction] Checkout Response body: ${res.data}');

      if (res.statusCode != 200 && res.statusCode != 201) {
        if (res.data is Map && res.data['success'] != true) {
          final msg = res.data['message'] ?? 'Transaksi gagal diproses';
          throw msg;
        }
      }

      var combinedData = <String, dynamic>{};
      if (res.data is Map<String, dynamic>) {
        combinedData.addAll(res.data as Map<String, dynamic>);
      }
      combinedData['success'] = true;

      return ServiceTransactionResponse.fromJson(combinedData);
    } on DioException catch (e) {
      debugPrint('[ServiceTransaction] DioError: ${e.response?.data}');
      final msg = e.response?.data?['message'];
      throw msg ?? 'Terjadi kesalahan jaringan ${e.message}';
    } catch (e) {
      debugPrint('[ServiceTransaction] Error: $e');
      throw e.toString();
    }
  }
}
