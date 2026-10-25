/// Opsi shift absensi (label statis dari BE, bukan model Shift POS).
class AttendanceShift {
  static const String shift1 = 'shift_1';
  static const String shift2 = 'shift_2';
  static const String middle = 'middle';

  /// Urutan pilihan untuk UI.
  static const List<String> values = [shift1, shift2, middle];

  /// Label ramah untuk ditampilkan ke user.
  static String label(String? value) {
    switch (value) {
      case shift1:
        return 'Shift 1 (Pagi)';
      case shift2:
        return 'Shift 2 (Sore)';
      case middle:
        return 'Middle';
      default:
        return value ?? '-';
    }
  }
}

/// Tugas di jadwal outlet (Tahap 1 SDM). Gudang dan SPV keliling tanpa tugas.
class ScheduleDuty {
  static const String cashier = 'cashier';
  static const String server = 'server';
  static const String both = 'both';

  static String label(String? value) {
    switch (value) {
      case cashier:
        return 'Kasir';
      case server:
        return 'Penyaji';
      case both:
        return 'Kasir & penyaji';
      default:
        return value ?? '';
    }
  }

  /// Tugas yang memegang POS dan laci.
  static bool holdsCashier(String? value) => value == cashier || value == both;
}

/// "07:00" → "07.00", cara jam ditulis di layar app ini.
String clockLabel(String? hhmm) => hhmm == null ? '' : hhmm.replaceAll(':', '.');

/// Jadwal yang ditempeli absen (`schedule` di respons absen).
class AttendanceSchedule {
  final int scheduleId;
  final int? shiftCodeId;
  final String shiftName;
  final String shortName;
  final String? duty;
  final String? startTime;
  final String? endTime;
  final String? checkoutLimit;

  const AttendanceSchedule({
    required this.scheduleId,
    required this.shiftName,
    this.shiftCodeId,
    this.shortName = '',
    this.duty,
    this.startTime,
    this.endTime,
    this.checkoutLimit,
  });

  /// "07.00–15.00", kosong bila kode shiftnya belum punya jam.
  String get hours => startTime == null || endTime == null
      ? ''
      : '${clockLabel(startTime)}–${clockLabel(endTime)}';

  factory AttendanceSchedule.fromJson(Map<String, dynamic> json) {
    return AttendanceSchedule(
      scheduleId: AttendanceModel._toInt(json['schedule_id']) ?? 0,
      shiftCodeId: AttendanceModel._toInt(json['shift_code_id']),
      shiftName: json['shift_name']?.toString() ?? '',
      shortName: json['short_name']?.toString() ?? '',
      duty: json['duty']?.toString(),
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      checkoutLimit: json['checkout_limit']?.toString(),
    );
  }
}

/// Tanda lembur pada satu absen.
class AttendanceOvertime {
  final int? markedBy;
  final String markedByName;
  final DateTime? markedAt;

  /// Absen pulang − jam selesai shift, menit penuh. Null selama belum pulang.
  final int? minutes;

  const AttendanceOvertime({this.markedBy, this.markedByName = '', this.markedAt, this.minutes});

  factory AttendanceOvertime.fromJson(Map<String, dynamic> json) {
    return AttendanceOvertime(
      markedBy: AttendanceModel._toInt(json['marked_by']),
      markedByName: json['marked_by_name']?.toString() ?? '',
      markedAt: AttendanceModel._toDate(json['marked_at']),
      minutes: AttendanceModel._toInt(json['minutes']),
    );
  }
}

/// Satu row absensi. Tanpa jadwal: satu per hari. Dengan jadwal (Tahap 1 SDM):
/// satu per baris jadwal, jadi dobel shift = dua row di tanggal yang sama.
/// Check-in membuat row, check-out meng-update row yang sama.
/// Lihat docs/api-attendance.md dan be-pos docs/api-absensi-jadwal-fe.md.
class AttendanceModel {
  final int id;
  final int userId;
  final int? branchId;
  final String attendanceDate; // YYYY-MM-DD
  final String? shift; // shift_1 | shift_2 | middle

  // Check-in
  final DateTime? checkInAt;
  final String? checkInPhotoUrl;
  final double? checkInLat;
  final double? checkInLng;
  final String? checkInStatus; // valid | outside_radius | no_branch_geo

  // Check-out
  final DateTime? checkOutAt;
  final String? checkOutPhotoUrl;
  final double? checkOutLat;
  final double? checkOutLng;
  final String? checkOutStatus;

  // Koreksi / audit
  final String? notes;
  final int? correctedBy;
  final DateTime? correctedAt;
  final DateTime? createdAt;

  // Jadwal (Tahap 1 SDM). Null = absen tanpa jadwal.
  final int? scheduleId;
  final int? lateMinutes;

  /// Pulang lewat batas absen pulang tanpa lembur.
  final bool checkoutPastLimit;
  final AttendanceSchedule? schedule;
  final AttendanceOvertime? overtime;

  const AttendanceModel({
    required this.id,
    required this.userId,
    required this.attendanceDate,
    this.branchId,
    this.shift,
    this.checkInAt,
    this.checkInPhotoUrl,
    this.checkInLat,
    this.checkInLng,
    this.checkInStatus,
    this.checkOutAt,
    this.checkOutPhotoUrl,
    this.checkOutLat,
    this.checkOutLng,
    this.checkOutStatus,
    this.notes,
    this.correctedBy,
    this.correctedAt,
    this.createdAt,
    this.scheduleId,
    this.lateMinutes,
    this.checkoutPastLimit = false,
    this.schedule,
    this.overtime,
  });

  /// Nama shift untuk layar: dari jadwal bila ada, kalau tidak dari label lama.
  String get shiftLabel => schedule?.shiftName.isNotEmpty == true
      ? schedule!.shiftName
      : AttendanceShift.label(shift);

  /// Sudah check-in hari ini.
  bool get hasCheckedIn => checkInAt != null;

  /// Sudah check-out hari ini.
  bool get hasCheckedOut => checkOutAt != null;

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: _toInt(json['id']) ?? 0,
      userId: _toInt(json['user_id']) ?? 0,
      branchId: _toInt(json['branch_id']),
      attendanceDate: json['attendance_date']?.toString() ?? '',
      shift: json['shift'] as String?,
      checkInAt: _toDate(json['check_in_at']),
      checkInPhotoUrl: json['check_in_photo_url'] as String?,
      checkInLat: _toDouble(json['check_in_lat']),
      checkInLng: _toDouble(json['check_in_lng']),
      checkInStatus: json['check_in_status'] as String?,
      checkOutAt: _toDate(json['check_out_at']),
      checkOutPhotoUrl: json['check_out_photo_url'] as String?,
      checkOutLat: _toDouble(json['check_out_lat']),
      checkOutLng: _toDouble(json['check_out_lng']),
      checkOutStatus: json['check_out_status'] as String?,
      notes: json['notes'] as String?,
      correctedBy: _toInt(json['corrected_by']),
      correctedAt: _toDate(json['corrected_at']),
      createdAt: _toDate(json['created_at']),
      scheduleId: _toInt(json['schedule_id']),
      lateMinutes: _toInt(json['late_minutes']),
      checkoutPastLimit: json['checkout_past_limit'] == true,
      schedule: json['schedule'] is Map
          ? AttendanceSchedule.fromJson(Map<String, dynamic>.from(json['schedule']))
          : null,
      overtime: json['overtime'] is Map
          ? AttendanceOvertime.fromJson(Map<String, dynamic>.from(json['overtime']))
          : null,
    );
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}
