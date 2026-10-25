/// Izin keluar: orang yang sedang bertugas di outlet keluar sebentar (Tahap 1
/// SDM). Catatan, bukan permintaan izin: tidak ada yang menyetujui.
class LeaveOutModel {
  final int id;
  final int attendanceId;
  final int userId;
  final int branchId;
  final String reason;
  final int? handoverUserId;
  final DateTime? outAt;
  final DateTime? backAt;

  /// Lupa menekan "Kembali", jadi ditutup saat absen pulang.
  final bool backAuto;

  // Hanya di daftar (`GET /leave-outs`).
  final String userName;
  final String handoverName;
  final String branchName;
  final int? minutes;

  const LeaveOutModel({
    required this.id,
    required this.reason,
    this.attendanceId = 0,
    this.userId = 0,
    this.branchId = 0,
    this.handoverUserId,
    this.outAt,
    this.backAt,
    this.backAuto = false,
    this.userName = '',
    this.handoverName = '',
    this.branchName = '',
    this.minutes,
  });

  bool get isOpen => backAt == null;

  factory LeaveOutModel.fromJson(Map<String, dynamic> json) {
    return LeaveOutModel(
      id: _toInt(json['id']) ?? 0,
      attendanceId: _toInt(json['attendance_id']) ?? 0,
      userId: _toInt(json['user_id']) ?? 0,
      branchId: _toInt(json['branch_id']) ?? 0,
      reason: json['reason']?.toString() ?? '',
      handoverUserId: _toInt(json['handover_user_id']),
      outAt: _toDate(json['out_at']),
      backAt: _toDate(json['back_at']),
      backAuto: json['back_auto'] == true,
      userName: json['user_name']?.toString() ?? '',
      handoverName: json['handover_name']?.toString() ?? '',
      branchName: json['branch_name']?.toString() ?? '',
      minutes: _toInt(json['minutes']),
    );
  }
}

/// Satu orang yang sedang bertugas (sudah absen masuk, belum pulang) di satu
/// lokasi — `GET /attendance/on-duty`.
class OnDutyModel {
  final int attendanceId;
  final int userId;
  final String userName;
  final DateTime? checkInAt;
  final int? lateMinutes;
  final String shiftName;
  final String? duty;
  final bool overtime;

  /// Izin keluar yang sedang berjalan, bila ada.
  final int? leaveOutId;

  const OnDutyModel({
    required this.attendanceId,
    required this.userId,
    required this.userName,
    this.checkInAt,
    this.lateMinutes,
    this.shiftName = '',
    this.duty,
    this.overtime = false,
    this.leaveOutId,
  });

  factory OnDutyModel.fromJson(Map<String, dynamic> json) {
    return OnDutyModel(
      attendanceId: _toInt(json['attendance_id']) ?? 0,
      userId: _toInt(json['user_id']) ?? 0,
      userName: json['user_name']?.toString() ?? '',
      checkInAt: _toDate(json['check_in_at']),
      lateMinutes: _toInt(json['late_minutes']),
      shiftName: json['shift_name']?.toString() ?? '',
      duty: json['duty']?.toString(),
      overtime: json['overtime'] == true,
      leaveOutId: _toInt(json['leave_out_id']),
    );
  }
}

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
