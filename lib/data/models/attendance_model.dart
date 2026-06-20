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

/// Satu row absensi = satu karyawan per hari.
/// Check-in membuat row, check-out meng-update row yang sama.
/// Lihat docs/api-attendance.md untuk shape lengkap.
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
  });

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
