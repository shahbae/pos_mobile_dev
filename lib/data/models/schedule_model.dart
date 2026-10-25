import 'package:pos_mobile/data/models/attendance_model.dart';

/// Kode shift kerja dari jadwal (Tahap 1 SDM): Shift 1, Shift 2, Middle, Libur,
/// Off. Beda dari [ShiftModel], yang adalah sesi kas (buka/tutup laci).
class ShiftCodeInfo {
  final int id;
  final String name;
  final String shortName;

  /// `work` | `off_day` (Libur) | `leave` (Off/Sakit/Cuti).
  final String kind;
  final String? startTime;
  final String? endTime;
  final String? checkoutLimit;

  const ShiftCodeInfo({
    required this.id,
    required this.name,
    this.shortName = '',
    this.kind = 'work',
    this.startTime,
    this.endTime,
    this.checkoutLimit,
  });

  bool get isWork => kind == 'work';

  /// "07.00–15.00", kosong bila jamnya belum diisi SPV.
  String get hours => startTime == null || endTime == null
      ? ''
      : '${clockLabel(startTime)}–${clockLabel(endTime)}';

  factory ShiftCodeInfo.fromJson(Map<String, dynamic> json) {
    return ShiftCodeInfo(
      id: _toInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      shortName: json['short_name']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'work',
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      checkoutLimit: json['checkout_limit']?.toString(),
    );
  }
}

/// Lokasi jadwal: cabang, gudang, atau SPV keliling.
class ScheduleLocation {
  /// `branch` | `warehouse` | `roving`.
  final String type;
  final int id;
  final String name;

  const ScheduleLocation({required this.type, this.id = 0, this.name = ''});

  bool get isBranch => type == 'branch';
  bool get isRoving => type == 'roving';

  factory ScheduleLocation.fromJson(Map<String, dynamic> json) {
    return ScheduleLocation(
      type: json['type']?.toString() ?? '',
      id: _toInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

/// Satu baris `GET /schedules/me` (jadwal saya; hanya bulan yang disetujui).
class MyScheduleEntry {
  final int id;
  final String date; // YYYY-MM-DD
  final String? duty;
  final ShiftCodeInfo shiftCode;
  final ScheduleLocation location;

  const MyScheduleEntry({
    required this.id,
    required this.date,
    required this.shiftCode,
    required this.location,
    this.duty,
  });

  factory MyScheduleEntry.fromJson(Map<String, dynamic> json) {
    return MyScheduleEntry(
      id: _toInt(json['id']) ?? 0,
      date: json['date']?.toString() ?? '',
      duty: json['duty']?.toString(),
      shiftCode: ShiftCodeInfo.fromJson(_map(json['shift_code'])),
      location: ScheduleLocation.fromJson(_map(json['location'])),
    );
  }
}

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}
