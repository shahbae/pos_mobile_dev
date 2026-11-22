import 'schedule_model.dart';

/// Lembur terjadwal (revisi owner 21 Nov 2026, `GET /me/overtimes`). Diatur di
/// sel jadwal oleh leader/SPV/finance; orangnya absen "masuk ulang" di lokasi
/// lembur (GPS dalam radius + selfie) lalu "pulang lembur".
class ScheduledOvertime {
  final int id;
  final String date; // YYYY-MM-DD
  final String startTime; // HH:MM
  final String endTime; // HH:MM; ≤ mulai = esok hari
  final String note;

  /// `scheduled` | `active` | `completed`.
  final String status;
  final ScheduleLocation home;
  final ScheduleLocation location;
  final bool crossLocation;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final DateTime? windowStart;
  final DateTime? windowEnd;
  final int? minutes;
  final int hours;

  const ScheduledOvertime({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.home,
    required this.location,
    this.note = '',
    this.crossLocation = false,
    this.checkInAt,
    this.checkOutAt,
    this.windowStart,
    this.windowEnd,
    this.minutes,
    this.hours = 0,
  });

  bool get isScheduled => status == 'scheduled';
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';

  String get hoursLabel => '${startTime.replaceAll(':', '.')}–${endTime.replaceAll(':', '.')}';

  String get statusLabel => switch (status) {
        'active' => 'Sedang lembur',
        'completed' => 'Selesai',
        _ => 'Terjadwal',
      };

  factory ScheduledOvertime.fromJson(Map<String, dynamic> j) {
    DateTime? t(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
    Map<String, dynamic> m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};
    int? n(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
    return ScheduledOvertime(
      id: n(j['id']) ?? 0,
      date: j['date']?.toString() ?? '',
      startTime: j['start_time']?.toString() ?? '',
      endTime: j['end_time']?.toString() ?? '',
      note: j['note']?.toString() ?? '',
      status: j['status']?.toString() ?? 'scheduled',
      home: ScheduleLocation.fromJson(m(j['home'])),
      location: ScheduleLocation.fromJson(m(j['location'])),
      crossLocation: j['cross_location'] == true,
      checkInAt: t(j['check_in_at']),
      checkOutAt: t(j['check_out_at']),
      windowStart: t(j['window_start']),
      windowEnd: t(j['window_end']),
      minutes: n(j['minutes']),
      hours: n(j['hours']) ?? 0,
    );
  }
}
