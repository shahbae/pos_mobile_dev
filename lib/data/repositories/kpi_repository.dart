import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/kpi_model.dart';
import '../services/api_services.dart';

/// Galat KPI dengan `code` dari server, supaya layar bisa bereaksi khusus
/// (mis. `checklist_already_sent` → muat ulang, rekan sudah memfoto).
class KpiApiError implements Exception {
  final String message;
  final String? code;
  final int? status;
  KpiApiError(this.message, {this.code, this.status});
  @override
  String toString() => message;
}

/// KPI tahap A di app kasir (Tahap 6 langkah 5). Foto selalu dikirim sebagai
/// byte yang sudah dibaca ke memori, bukan path: folder cache kamera boleh
/// dikosongkan Android kapan saja (pelajaran "PathNotFoundException", 10 Okt).
class KpiRepository {
  final ApiService api;
  KpiRepository(this.api);

  // ------------------------------------------------------------ skor

  /// `GET /me/kpi?period=` — skor sendiri. `409 kpi_not_active` →
  /// [KpiNotActive].
  Future<MyKpi> mine({String? period}) async {
    try {
      final res = await api.dio.get('/me/kpi', queryParameters: {if (period != null) 'period': period});
      return MyKpi.fromJson(_data(res));
    } on DioException catch (e) {
      throw _notActiveOr(e, 'Gagal memuat skor KPI');
    }
  }

  /// `GET /kpi/team?period=` — leader, outlet yang dipimpinnya.
  Future<KpiTeam> team({String? period}) async {
    try {
      final res = await api.dio.get('/kpi/team', queryParameters: {if (period != null) 'period': period});
      return KpiTeam.fromJson(_data(res));
    } on DioException catch (e) {
      throw _notActiveOr(e, 'Gagal memuat skor tim');
    }
  }

  /// `POST /kpi/disputes` (multipart). Satu kejadian hanya bisa disanggah
  /// sekali, paling lambat 3 hari sesudah berlaku.
  Future<KpiDispute> dispute({required int eventId, required String reason, Uint8List? photo}) async {
    try {
      final res = await api.dio.post(
        '/kpi/disputes',
        data: FormData.fromMap({
          'event_id': '$eventId',
          'reason': reason,
          if (photo != null) 'photo': MultipartFile.fromBytes(photo, filename: 'sanggahan-$eventId.jpg'),
        }),
        options: Options(contentType: 'multipart/form-data'),
      );
      return KpiDispute.fromJson(_data(res));
    } on DioException catch (e) {
      throw _error(e, 'Gagal mengirim sanggahan');
    }
  }

  // ------------------------------------------------------------ ceklis foto

  /// `GET /me/photo-checklist` — set shift hari ini (dan kemarin bila
  /// shiftnya belum berakhir), termasuk kiriman rekan.
  Future<List<ChecklistSet>> myChecklist() async {
    try {
      final res = await api.dio.get('/me/photo-checklist');
      final data = res.data['data'];
      if (data is! List) return const [];
      return [
        for (final e in data)
          if (e is Map) ChecklistSet.fromJson(Map<String, dynamic>.from(e)),
      ];
    } on DioException catch (e) {
      throw _error(e, 'Gagal memuat ceklis foto');
    }
  }

  /// `POST /me/photo-checklist` — satu butir. [photo] dari kamera; atau
  /// [unusedReason] untuk butir yang boleh "belum dipakai" (tanpa foto).
  Future<void> submitChecklist({
    required int scheduleId,
    required int itemId,
    Uint8List? photo,
    String? unusedReason,
  }) async {
    final unused = photo == null;
    try {
      await api.dio.post(
        '/me/photo-checklist',
        data: FormData.fromMap({
          'schedule_id': '$scheduleId',
          'item_id': '$itemId',
          if (unused) ...{'unused': 'true', 'unused_reason': unusedReason ?? ''},
          if (!unused) 'photo': MultipartFile.fromBytes(photo, filename: 'ceklis-$scheduleId-$itemId.jpg'),
        }),
        options: Options(contentType: 'multipart/form-data'),
      );
    } on DioException catch (e) {
      throw _error(e, 'Gagal mengirim foto ceklis');
    }
  }

  // ------------------------------------------------------------ komplain kualitas

  /// `POST /complaints` — komplain kualitas atas kiriman yang sudah diterima
  /// (Tahap 7, PRD-C1). Finance memvalidasinya; yang valid memotong skor tim
  /// Produksi gudang pengirim, tidak pernah skor crew.
  ///
  /// Outlet, waktu, dan jenis ikut dikirim walau leader biasa tidak
  /// membutuhkannya: akun leader yang juga SPV melewati jalur pencatat WA di
  /// server, yang mewajibkan ketiganya.
  Future<void> createQualityComplaint({
    required int shipmentId,
    required int branchId,
    required String content,
    required Uint8List photo,
    DateTime? occurredAt,
  }) async {
    final at = occurredAt ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    try {
      await api.dio.post(
        '/complaints',
        data: FormData.fromMap({
          'shipment_id': '$shipmentId',
          'branch_id': '$branchId',
          'kind': 'production_quality',
          'occurred_at': '${at.year}-${two(at.month)}-${two(at.day)} ${two(at.hour)}:${two(at.minute)}',
          'content': content.trim(),
          'photo': MultipartFile.fromBytes(photo, filename: 'komplain-kiriman-$shipmentId.jpg'),
        }),
        options: Options(contentType: 'multipart/form-data'),
      );
    } on DioException catch (e) {
      throw _error(e, 'Gagal mengirim komplain');
    }
  }

  // ------------------------------------------------------------ setoran

  /// `GET /cash-deposits` — leader selalu dibatasi server ke outlet yang
  /// dipimpinnya.
  Future<List<CashDeposit>> cashDeposits({int page = 1, int limit = 50}) async {
    try {
      final res = await api.dio.get('/cash-deposits', queryParameters: {'page': page, 'limit': limit});
      final items = (res.data['data'] as Map?)?['items'];
      if (items is! List) return const [];
      return [
        for (final e in items)
          if (e is Map) CashDeposit.fromJson(Map<String, dynamic>.from(e)),
      ];
    } on DioException catch (e) {
      throw _error(e, 'Gagal memuat setoran');
    }
  }

  /// `POST /cash-deposits` (multipart, isian `photo` berulang). Jam transfer =
  /// jam unggah di server.
  Future<CashDeposit> createCashDeposit({
    required String operationalDate,
    required int amount,
    required List<Uint8List> photos,
    String note = '',
  }) async {
    try {
      final form = FormData.fromMap({
        'operational_date': operationalDate,
        'amount': '$amount',
        'note': note,
      });
      for (var i = 0; i < photos.length; i++) {
        form.files.add(MapEntry(
          'photo',
          MultipartFile.fromBytes(photos[i], filename: 'setoran-$operationalDate-${i + 1}.jpg'),
        ));
      }
      final res = await api.dio.post(
        '/cash-deposits',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      return CashDeposit.fromJson(_data(res));
    } on DioException catch (e) {
      throw _error(e, 'Gagal mengirim setoran');
    }
  }

  // ------------------------------------------------------------ sidak

  /// `GET /inspection-items` — app memakai yang aktif saja.
  Future<List<InspectionItem>> inspectionItems() async {
    try {
      final res = await api.dio.get('/inspection-items');
      final data = res.data['data'];
      if (data is! List) return const [];
      final items = [
        for (final e in data)
          if (e is Map) InspectionItem.fromJson(Map<String, dynamic>.from(e)),
      ].where((i) => i.isActive).toList();
      items.sort((a, b) {
        final g = _groupRank(a.group).compareTo(_groupRank(b.group));
        if (g != 0) return g;
        final s = a.sort.compareTo(b.sort);
        return s != 0 ? s : a.id.compareTo(b.id);
      });
      return items;
    } on DioException catch (e) {
      throw _error(e, 'Gagal memuat butir sidak');
    }
  }

  static int _groupRank(String g) {
    final i = inspectionGroupOrder.indexOf(g);
    return i < 0 ? inspectionGroupOrder.length : i;
  }

  /// `GET /inspections?branch_id=&from=&to=` — terbaru di atas.
  Future<List<Inspection>> inspections({int? branchId, String? from, String? to, int limit = 50}) async {
    try {
      final res = await api.dio.get('/inspections', queryParameters: {
        if (branchId != null) 'branch_id': branchId,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        'limit': limit,
      });
      final items = (res.data['data'] as Map?)?['items'];
      if (items is! List) return const [];
      return [
        for (final e in items)
          if (e is Map) Inspection.fromJson(Map<String, dynamic>.from(e)),
      ];
    } on DioException catch (e) {
      throw _error(e, 'Gagal memuat sidak');
    }
  }

  /// `GET /inspections/:id` — dengan hasil tiap butir.
  Future<Inspection> inspection(int id) async {
    try {
      final res = await api.dio.get('/inspections/$id');
      return Inspection.fromJson(_data(res));
    } on DioException catch (e) {
      throw _error(e, 'Gagal memuat sidak');
    }
  }

  /// Batas kirim sidak: server memberi tenggat 3 menit untuk badan sampai
  /// 30 MB. Tenggat kirim bawaan (60 dtk) terlalu pendek untuk 30 foto di
  /// sinyal outlet.
  static const inspectionSendTimeout = Duration(minutes: 3);

  /// `POST /inspections` (multipart). Semua butir aktif wajib dijawab tepat
  /// sekali; foto temuan opsional per butir.
  Future<Inspection> createInspection({
    required int branchId,
    required double latitude,
    required double longitude,
    required Uint8List inspectorPhoto,
    required List<InspectionAnswer> answers,
    String notes = '',
    String followUp = '',
  }) async {
    final form = FormData.fromMap({
      'branch_id': '$branchId',
      'latitude': '$latitude',
      'longitude': '$longitude',
      'notes': notes,
      'follow_up': followUp,
      'results': jsonEncode([for (final a in answers) a.toJson()]),
      'photo': MultipartFile.fromBytes(inspectorPhoto, filename: 'sidak-$branchId.jpg'),
    });
    for (final a in answers) {
      if (a.photo != null) {
        form.files.add(MapEntry('photo_${a.itemId}', MultipartFile.fromBytes(a.photo!, filename: 'temuan-${a.itemId}.jpg')));
      }
    }
    try {
      final res = await api.dio.post(
        '/inspections',
        data: form,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: inspectionSendTimeout,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return Inspection.fromJson(_data(res));
    } on DioException catch (e) {
      throw _error(e, 'Gagal mengirim sidak');
    }
  }

  // ------------------------------------------------------------ bantu

  Map<String, dynamic> _data(Response<dynamic> res) => Map<String, dynamic>.from(res.data['data'] as Map);

  Exception _notActiveOr(DioException e, String fallback) {
    final err = _error(e, fallback);
    if (err.code == 'kpi_not_active') return KpiNotActive(err.message);
    return err;
  }

  KpiApiError _error(DioException e, String fallback) {
    final data = e.response?.data;
    final status = e.response?.statusCode;
    final code = data is Map ? data['code']?.toString() : null;
    final msg = data is Map ? (data['message'] ?? data['error'])?.toString() : null;
    if (msg != null && msg.isNotEmpty) return KpiApiError(msg, code: code, status: status);
    if (e.response == null) return KpiApiError('$fallback: periksa koneksi internet');
    return KpiApiError('$fallback ($status)', code: code, status: status);
  }
}

/// Jawaban satu butir sidak.
class InspectionAnswer {
  final int itemId;
  final bool passed;
  final String note;
  final Uint8List? photo;

  const InspectionAnswer({required this.itemId, required this.passed, this.note = '', this.photo});

  Map<String, dynamic> toJson() => {'item_id': itemId, 'passed': passed, 'note': note};
}
