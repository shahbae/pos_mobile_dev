import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/payroll_model.dart';
import '../services/api_services.dart';

/// Slip gaji, pinjaman, dan serah pinjaman tunai (Tahap 2 SDM).
///
/// Karyawan hanya melihat slip yang periodenya sudah disetujui owner; slip
/// orang lain dan slip yang belum terbit sama-sama 404 di BE.
class PayrollRepository {
  final ApiService api;
  PayrollRepository(this.api);

  Future<List<MyPayslipRow>> myPayslips() => _list(
        () => api.dio.get('/me/payslips'),
        MyPayslipRow.fromJson,
        'Gagal memuat slip gaji',
      );

  Future<PayslipView> payslip(int id) =>
      _one(() => api.dio.get('/me/payslips/$id'), PayslipView.fromJson, 'Gagal memuat slip');

  /// Satu komplain terbuka per slip; owner yang memutuskan.
  Future<PayslipView> complain(int payslipId, String message) => _one(
        () => api.dio.post('/me/payslips/$payslipId/complaints', data: {'message': message}),
        PayslipView.fromJson,
        'Gagal mengirim komplain',
      );

  /// Unduh slip PDF ke folder sementara aplikasi; mengembalikan path berkasnya.
  /// Folder yang sama dengan unduhan APK, yang sudah terbukti bisa dibuka
  /// `open_filex` di HP outlet.
  Future<String> downloadPayslipPdf(int payslipId, String payday) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/slip');
    if (!await dir.exists()) await dir.create(recursive: true);
    final path = '${dir.path}/slip-gaji-$payday.pdf';
    try {
      await api.dio.download(
        '/me/payslips/$payslipId/pdf',
        path,
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );
      return path;
    } on DioException catch (e) {
      // Galat dari endpoint berkas datang sebagai JSON yang ikut tertulis ke
      // berkas tujuan; buang supaya tidak terbuka sebagai PDF rusak.
      final f = File(path);
      if (await f.exists()) await f.delete();
      throw _message(e, 'Gagal mengunduh slip');
    }
  }

  Future<List<LoanModel>> myLoans() =>
      _list(() => api.dio.get('/me/loans'), LoanModel.fromJson, 'Gagal memuat pinjaman');

  /// [amount] rupiah utuh. Tanpa batas nominal maupun jumlah (keputusan owner).
  Future<LoanModel> requestLoan({required int amount, required String purpose}) => _one(
        () => api.dio.post('/me/loans', data: {'amount': '$amount', 'purpose': purpose}),
        LoanModel.fromJson,
        'Gagal mengajukan pinjaman',
      );

  Future<LoanModel> cancelLoan(int id) =>
      _one(() => api.dio.post('/me/loans/$id/cancel'), LoanModel.fromJson, 'Gagal membatalkan');

  /// Pinjaman tunai yang ditunjuk finance ke laci cabang di token.
  Future<List<LoanModel>> cashPending() => _list(
        () => api.dio.get('/loans/cash-pending'),
        LoanModel.fromJson,
        'Gagal memuat pinjaman tunai',
      );

  /// Serahkan uang dari laci. Foto serah terima wajib; butuh shift kasir yang
  /// sedang buka di cabang ini (422 dari BE bila belum).
  Future<LoanModel> handOut(int id, String photoPath) async {
    final filename = photoPath.split(RegExp(r'[\\/]')).last;
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(photoPath, filename: filename),
    });
    return _one(
      () => api.dio.post('/loans/$id/hand-out',
          data: form, options: Options(contentType: 'multipart/form-data')),
      LoanModel.fromJson,
      'Gagal mencatat serah terima',
    );
  }

  Future<List<T>> _list<T>(Future<Response<dynamic>> Function() send,
      T Function(Map<String, dynamic>) parse, String fallback) async {
    try {
      final res = await send();
      final data = res.data['data'];
      if (data is! List) return const [];
      return [
        for (final row in data)
          if (row is Map) parse(Map<String, dynamic>.from(row)),
      ];
    } on DioException catch (e) {
      throw _message(e, fallback);
    }
  }

  Future<T> _one<T>(Future<Response<dynamic>> Function() send,
      T Function(Map<String, dynamic>) parse, String fallback) async {
    try {
      final res = await send();
      final data = res.data['data'];
      if (data is! Map) throw fallback;
      return parse(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw _message(e, fallback);
    }
  }

  /// Pesan BE untuk penggajian sudah berbahasa Indonesia ("buka shift kasir
  /// dulu; …", "komplainmu untuk slip ini masih menunggu keputusan owner"),
  /// jadi diteruskan apa adanya. Yang diganti hanya yang teknis.
  String _message(DioException e, String fallback) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return 'Tidak bisa menghubungi server. Periksa koneksi lalu coba lagi.';
      default:
        break;
    }
    final data = e.response?.data;
    final raw = (data is Map ? (data['message'] ?? data['error']) : null)?.toString();
    final status = e.response?.statusCode;
    if (status == 404 && (raw == null || raw == 'data tidak ditemukan')) {
      return 'Data tidak ditemukan. Mungkin sudah berubah; tarik untuk memuat ulang.';
    }
    if (raw == null || raw.isEmpty) return '$fallback (${status ?? e.message})';
    final m = raw.toLowerCase();
    if (m.contains('5mb')) return 'Ukuran foto maksimal 5 MB.';
    if (m.contains('jpg') || m.contains('png')) return 'Format foto harus JPG, PNG, atau WEBP.';
    if (m == 'isian tidak valid') return 'Isian belum lengkap atau tidak valid.';
    return '${raw[0].toUpperCase()}${raw.substring(1)}';
  }
}
