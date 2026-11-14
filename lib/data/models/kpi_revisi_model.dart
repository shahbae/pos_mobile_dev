/// Revisi KPI owner 11 Nov 2026 (be-pos docs/api-revisi-kpi-11nov-fe.md):
/// sesi Live TikTok (C3.4), arahan dan evaluasi SPV untuk leader (SPV-A2).
library;

int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
int? _intOrNull(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
double? _dblOrNull(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
String _str(dynamic v) => v?.toString() ?? '';
String? _strOrNull(dynamic v) {
  final s = v?.toString() ?? '';
  return s.isEmpty ? null : s;
}

DateTime? _time(dynamic v) {
  final s = v?.toString() ?? '';
  return s.isEmpty ? null : DateTime.tryParse(s)?.toLocal();
}

// ------------------------------------------------------------ Live (C3.4)

/// Satu sesi Live yang sudah dimulai (atau dinilai "tidak dimulai").
class LiveSession {
  final int id;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final bool closedBySystem;
  final int? durationMinutes;
  final String? screenshotUrl;
  final DateTime? screenshotAt;

  /// `''` tertib, `no_start`, `not_closed`, `off_schedule`, `short`.
  final String problem;
  final DateTime? evaluatedAt;

  /// `''` / `pending` / `approved` / `cancelled`.
  final String reviewStatus;
  final double? reviewPoints;
  final DateTime? reviewedAt;
  final String reviewNote;

  /// Kejadian KPI dari sesi ini: `PENDING` = usulan menunggu SPV.
  final String eventStatus;
  final double? eventPoints;

  const LiveSession({
    required this.id,
    this.startedAt,
    this.endedAt,
    this.closedBySystem = false,
    this.durationMinutes,
    this.screenshotUrl,
    this.screenshotAt,
    this.problem = '',
    this.evaluatedAt,
    this.reviewStatus = '',
    this.reviewPoints,
    this.reviewedAt,
    this.reviewNote = '',
    this.eventStatus = '',
    this.eventPoints,
  });

  factory LiveSession.fromJson(Map<String, dynamic> j) => LiveSession(
    id: _int(j['id']),
    startedAt: _time(j['started_at']),
    endedAt: _time(j['ended_at']),
    closedBySystem: j['closed_by_system'] == true,
    durationMinutes: _intOrNull(j['duration_minutes']),
    screenshotUrl: _strOrNull(j['screenshot_url']),
    screenshotAt: _time(j['screenshot_at']),
    problem: _str(j['problem']),
    evaluatedAt: _time(j['evaluated_at']),
    reviewStatus: _str(j['review_status']),
    reviewPoints: _dblOrNull(j['review_points']),
    reviewedAt: _time(j['reviewed_at']),
    reviewNote: _str(j['review_note']),
    eventStatus: _str(j['event_status']),
    eventPoints: _dblOrNull(j['event_points']),
  );

  bool get running => startedAt != null && endedAt == null;

  /// Penilaian sistem dalam kalimat; kosong bila belum dinilai.
  String get problemLabel {
    if (evaluatedAt == null) return '';
    switch (problem) {
      case '':
        return 'Tertib';
      case 'no_start':
        return 'Tidak menekan Mulai';
      case 'not_closed':
        return 'Lupa menekan Selesai';
      case 'off_schedule':
        return 'Di luar jam shift';
      case 'short':
        return 'Kurang dari 60 menit';
      default:
        return problem;
    }
  }

  /// Keadaan potongan untuk karyawan.
  String get verdictLabel {
    if (reviewedAt != null) {
      if (reviewStatus == 'cancelled') return 'Usulan potongan dibatalkan SPV';
      final p = reviewPoints ?? eventPoints ?? 0;
      return p == 0 ? 'SPV: tanpa potongan' : 'SPV: potongan ${_pts(p)}';
    }
    if (eventStatus == 'PENDING' && eventPoints != null) return 'Usulan potongan ${_pts(eventPoints!)}, menunggu SPV';
    if (evaluatedAt != null && problem.isNotEmpty) return 'Menunggu keputusan SPV';
    return '';
  }
}

String _pts(double v) {
  final s = v.abs() == v.abs().roundToDouble() ? v.abs().toStringAsFixed(0) : v.abs().toString().replaceAll('.', ',');
  return v < 0 ? '−$s' : s;
}

/// Satu jadwal Live milik orang yang login (`GET /me/live-sessions`).
class LiveSlot {
  final int scheduleId;
  final String date;
  final String shiftName;
  final DateTime? shiftStart;
  final DateTime? shiftEnd;
  final LiveSession? session;
  final bool canStart;
  final bool canFinish;
  final bool canAddScreenshot;

  const LiveSlot({
    required this.scheduleId,
    required this.date,
    this.shiftName = '',
    this.shiftStart,
    this.shiftEnd,
    this.session,
    this.canStart = false,
    this.canFinish = false,
    this.canAddScreenshot = false,
  });

  factory LiveSlot.fromJson(Map<String, dynamic> j) => LiveSlot(
    scheduleId: _int(j['schedule_id']),
    date: _str(j['date']),
    shiftName: _str(j['shift_name']),
    shiftStart: _time(j['shift_start']),
    shiftEnd: _time(j['shift_end']),
    session: j['session'] is Map ? LiveSession.fromJson(Map<String, dynamic>.from(j['session'] as Map)) : null,
    canStart: j['can_start'] == true,
    canFinish: j['can_finish'] == true,
    canAddScreenshot: j['can_add_screenshot'] == true,
  );

  /// Perlu tindakan karyawan sekarang.
  bool get actionable => canStart || canFinish || canAddScreenshot;
}

// ---------------------------------------------------- Arahan SPV (SPV-A2)

class LeaderDirective {
  final int id;
  final String spvName;
  final String branchName;
  final String content;
  final String? photoUrl;
  final DateTime? dueAt;
  final DateTime? doneAt;
  final String doneNote;
  final String? donePhotoUrl;
  final DateTime? checkedAt;

  /// `done` / `not_done` sesudah dicek SPV.
  final String checkResult;
  final String checkNote;
  final DateTime? createdAt;

  /// `open` / `done` / `checked`.
  final String state;

  const LeaderDirective({
    required this.id,
    this.spvName = '',
    this.branchName = '',
    this.content = '',
    this.photoUrl,
    this.dueAt,
    this.doneAt,
    this.doneNote = '',
    this.donePhotoUrl,
    this.checkedAt,
    this.checkResult = '',
    this.checkNote = '',
    this.createdAt,
    this.state = 'open',
  });

  factory LeaderDirective.fromJson(Map<String, dynamic> j) => LeaderDirective(
    id: _int(j['id']),
    spvName: _str(j['spv_name']),
    branchName: _str(j['branch_name']),
    content: _str(j['content']),
    photoUrl: _strOrNull(j['photo_url']),
    dueAt: _time(j['due_at']),
    doneAt: _time(j['done_at']),
    doneNote: _str(j['done_note']),
    donePhotoUrl: _strOrNull(j['done_photo_url']),
    checkedAt: _time(j['checked_at']),
    checkResult: _str(j['check_result']),
    checkNote: _str(j['check_note']),
    createdAt: _time(j['created_at']),
    state: j['state']?.toString().isNotEmpty == true ? j['state'].toString() : 'open',
  );

  bool get isOpen => state == 'open';
  bool get isChecked => state == 'checked';

  /// Leader masih boleh menandai (atau memperbarui tanda) dikerjakan.
  bool get canMarkDone => !isChecked;

  String get stateLabel {
    switch (state) {
      case 'done':
        return 'Dikerjakan, menunggu dicek SPV';
      case 'checked':
        return checkResult == 'done' ? 'Dicek SPV: terlaksana' : 'Dicek SPV: tidak terlaksana';
      default:
        return 'Belum dikerjakan';
    }
  }
}

// ---------------------------------------------- Evaluasi bulanan (SPV-A2d)

class LeaderEvaluation {
  final String period;
  final String content;
  final String spvName;
  final String? photoUrl;
  final DateTime? updatedAt;

  const LeaderEvaluation({required this.period, this.content = '', this.spvName = '', this.photoUrl, this.updatedAt});

  /// Satu baris `GET /me/evaluations`; null bila bulan itu belum dievaluasi.
  static LeaderEvaluation? tryFrom(Map<String, dynamic> j) {
    final e = j['evaluation'];
    if (e is! Map) return null;
    return LeaderEvaluation(
      period: _str(j['period']),
      content: _str(e['content']),
      spvName: _str(j['spv_name']),
      photoUrl: _strOrNull(j['photo_url']),
      updatedAt: _time(e['updated_at']),
    );
  }
}
