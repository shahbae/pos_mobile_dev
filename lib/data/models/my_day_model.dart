import 'package:pos_mobile/data/models/attendance_model.dart';
import 'package:pos_mobile/data/models/schedule_model.dart';

/// Status satu shift hari ini dari sisi orangnya (`GET /attendance/me/day`).
enum MyDayShiftStatus {
  /// Jendela absen masuk belum dibuka.
  upcoming,

  /// Bisa absen masuk sekarang.
  open,

  /// Sudah absen masuk, belum pulang.
  checkedIn,

  /// Sudah absen pulang.
  done,

  /// Lewat tanpa absen (belum dinilai job alpa).
  missed,

  /// Tercatat alpa.
  absent,
}

MyDayShiftStatus _statusOf(String? raw) {
  switch (raw) {
    case 'open':
      return MyDayShiftStatus.open;
    case 'checked_in':
      return MyDayShiftStatus.checkedIn;
    case 'done':
      return MyDayShiftStatus.done;
    case 'missed':
      return MyDayShiftStatus.missed;
    case 'absent':
      return MyDayShiftStatus.absent;
    default:
      return MyDayShiftStatus.upcoming;
  }
}

/// Satu baris jadwal kerja hari ini (atau shift kemarin yang masih berjalan).
class MyDayShift {
  final int scheduleId;
  final String date;
  final ShiftCodeInfo shiftCode;
  final String? duty;
  final ScheduleLocation location;

  /// Jam absen masuk dibuka (`checkin_open_minutes` sebelum mulai).
  final DateTime? opensAt;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final MyDayShiftStatus status;
  final int? attendanceId;

  const MyDayShift({
    required this.scheduleId,
    required this.date,
    required this.shiftCode,
    required this.location,
    required this.status,
    this.duty,
    this.opensAt,
    this.startsAt,
    this.endsAt,
    this.attendanceId,
  });

  /// Status menurut jam server [serverNow]. Server menilainya saat diminta;
  /// layar yang dibiarkan terbuka menilai ulang sendiri supaya tombol absen
  /// masuk menyala tepat saat jendelanya dibuka, tanpa harus muat ulang.
  MyDayShiftStatus statusAt(DateTime serverNow) {
    switch (status) {
      case MyDayShiftStatus.upcoming:
        if (opensAt != null && !serverNow.isBefore(opensAt!)) {
          return endsAt != null && !serverNow.isBefore(endsAt!)
              ? MyDayShiftStatus.missed
              : MyDayShiftStatus.open;
        }
        return status;
      case MyDayShiftStatus.open:
        if (endsAt != null && !serverNow.isBefore(endsAt!)) return MyDayShiftStatus.missed;
        return status;
      default:
        return status;
    }
  }

  /// "Shift 1 · Kasir · 07.00–15.00".
  String get title => [
        shiftCode.name,
        if (duty != null && duty!.isNotEmpty) ScheduleDuty.label(duty),
        if (shiftCode.hours.isNotEmpty) shiftCode.hours,
      ].join(' · ');

  factory MyDayShift.fromJson(Map<String, dynamic> json) {
    return MyDayShift(
      scheduleId: _toInt(json['schedule_id']) ?? 0,
      date: json['date']?.toString() ?? '',
      shiftCode: ShiftCodeInfo.fromJson(_map(json['shift_code'])),
      duty: json['duty']?.toString(),
      location: ScheduleLocation.fromJson(_map(json['location'])),
      opensAt: _toDate(json['opens_at']),
      startsAt: _toDate(json['starts_at']),
      endsAt: _toDate(json['ends_at']),
      status: _statusOf(json['status']?.toString()),
      attendanceId: _toInt(json['attendance_id']),
    );
  }
}

/// Lembur yang sudah masuk dan belum pulang (revisi owner 26 Nov 2026).
/// Selama ini ada, orangnya dihitung bertugas di lokasi lembur dengan [duty].
class MyDayOvertime {
  final int id;

  /// `cashier` | `server` | `both`.
  final String duty;
  final ScheduleLocation location;

  const MyDayOvertime({required this.id, this.duty = 'both', required this.location});

  factory MyDayOvertime.fromJson(Map<String, dynamic> json) => MyDayOvertime(
        id: _toInt(json['id']) ?? 0,
        duty: json['duty']?.toString() ?? 'both',
        location: json['location'] is Map
            ? ScheduleLocation.fromJson(Map<String, dynamic>.from(json['location'] as Map))
            : const ScheduleLocation(type: ''),
      );
}

/// Hari saya: shift hari ini, absen hari ini, dan apakah masih ada shift lagi.
class MyDay {
  final String date;

  /// Jam server saat dijawab, dan jam HP saat jawaban diterima. Selisihnya
  /// menutup jam HP yang meleset, supaya penilaian ulang di [serverNow] tetap
  /// mengikuti jam server.
  final DateTime? now;
  final DateTime receivedAt;
  final int checkinOpenMinutes;
  final List<MyDayShift> shifts;
  final List<AttendanceModel> attendances;
  final int? openAttendanceId;

  /// Masih ada shift kerja hari ini yang belum diabsen dan belum lewat. App
  /// terkunci sesudah absen pulang HANYA bila ini false.
  final bool hasNextShift;

  /// Lembur yang sedang berjalan (revisi owner 26 Nov 2026), atau null.
  final MyDayOvertime? activeOvertime;

  /// Absen terakhir hari ini ditutup sistem di batas absen pulang.
  final bool autoCheckout;

  MyDay({
    required this.date,
    required this.shifts,
    required this.attendances,
    this.now,
    DateTime? receivedAt,
    this.checkinOpenMinutes = 20,
    this.openAttendanceId,
    this.hasNextShift = false,
    this.activeOvertime,
    this.autoCheckout = false,
  }) : receivedAt = receivedAt ?? DateTime.now();

  /// Server lama (tanpa `/attendance/me/day`): satu absen per hari, tanpa jadwal.
  factory MyDay.fromToday(AttendanceModel? att) {
    final open = att != null && att.hasCheckedIn && !att.hasCheckedOut;
    return MyDay(
      date: att?.attendanceDate ?? '',
      shifts: const [],
      attendances: [if (att != null && att.hasCheckedIn) att],
      openAttendanceId: open ? att.id : null,
    );
  }

  factory MyDay.fromJson(Map<String, dynamic> json, {DateTime? receivedAt}) {
    List<Map<String, dynamic>> list(dynamic v) => v is List
        ? [for (final e in v) if (e is Map) Map<String, dynamic>.from(e)]
        : const [];
    return MyDay(
      date: json['date']?.toString() ?? '',
      now: _toDate(json['now']),
      receivedAt: receivedAt,
      checkinOpenMinutes: _toInt(json['checkin_open_minutes']) ?? 20,
      shifts: list(json['shifts']).map(MyDayShift.fromJson).toList(),
      attendances: list(json['attendances']).map(AttendanceModel.fromJson).toList(),
      openAttendanceId: _toInt(json['open_attendance_id']),
      hasNextShift: json['has_next_shift'] == true,
      activeOvertime: json['active_overtime'] is Map
          ? MyDayOvertime.fromJson(Map<String, dynamic>.from(json['active_overtime'] as Map))
          : null,
      autoCheckout: json['auto_checkout'] == true,
    );
  }

  DateTime get serverNow {
    final n = now;
    if (n == null) return DateTime.now();
    return n.add(DateTime.now().difference(receivedAt));
  }

  /// Absen yang belum pulang (dobel shift: yang terakhir masuk).
  AttendanceModel? get openAttendance {
    if (openAttendanceId != null) {
      for (final a in attendances) {
        if (a.id == openAttendanceId) return a;
      }
    }
    for (final a in attendances.reversed) {
      if (a.hasCheckedIn && !a.hasCheckedOut) return a;
    }
    return null;
  }

  bool get hasAttendance => attendances.any((a) => a.hasCheckedIn);

  /// Sedang bertugas (revisi owner 26 Nov 2026): absen masuk belum pulang, atau
  /// lembur yang sudah masuk.
  bool get onDuty => openAttendance != null || activeOvertime != null;

  /// Posisi yang berlaku sekarang: posisi lembur bila sedang lembur, selain itu
  /// posisi shift yang sedang diabsen. null = tidak diketahui (tanpa jadwal).
  String? get currentDuty {
    final ot = activeOvertime;
    if (ot != null) return ot.duty;
    for (final s in shifts) {
      if (s.status == MyDayShiftStatus.checkedIn) return s.duty;
    }
    return null;
  }

  /// Shift yang bisa diabsen masuk sekarang. Yang paling awal didahulukan,
  /// sama seperti server memilihnya.
  MyDayShift? get currentShift {
    final at = serverNow;
    for (final s in shifts) {
      if (s.statusAt(at) == MyDayShiftStatus.open) return s;
    }
    return null;
  }

  /// Shift berikutnya yang jendelanya belum dibuka.
  MyDayShift? get nextShift {
    final at = serverNow;
    for (final s in shifts) {
      if (s.statusAt(at) == MyDayShiftStatus.upcoming) return s;
    }
    return null;
  }

  /// Shift hari ini di satu cabang (dipakai untuk tugas kasir/penyaji).
  List<MyDayShift> shiftsAtBranch(int? branchId) => [
        for (final s in shifts)
          if (branchId != null && s.location.isBranch && s.location.id == branchId) s,
      ];
}

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}
