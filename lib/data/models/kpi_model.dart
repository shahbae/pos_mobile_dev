// KPI tahap A (Tahap 6 SDM): skor sendiri, kejadian & sanggahan, tim leader,
// ceklis foto, setoran, dan sidak. Kontrak: be-pos `docs/api-kpi-tahap6-fe.md`.

DateTime? _time(dynamic v) => v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
String? _str(dynamic v) => v is String && v.isNotEmpty ? v : null;
int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
int? _intOrNull(dynamic v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
bool _bool(dynamic v) => v == true;

/// Angka dari server: `float64` dikirim sebagai angka, `decimal` (nominal
/// setoran) sebagai string.
double? _numOrNull(dynamic v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
double _num(dynamic v) => _numOrNull(v) ?? 0;

/// Kolom `date` MySQL keluar sebagai waktu tengah malam (`2026-11-04T00:00:00+07:00`
/// atau `...Z`). Sepuluh karakter pertamanya selalu tanggal yang dimaksud.
String _ymd(dynamic v) {
  final s = '${v ?? ''}';
  return s.length >= 10 ? s.substring(0, 10) : s;
}

List<Map<String, dynamic>> _maps(dynamic v) => [
  if (v is List)
    for (final e in v)
      if (e is Map) Map<String, dynamic>.from(e),
];

// ---------------------------------------------------------------- skor

/// Label predikat dari server dipakai apa adanya; warnanya di sini.
const kpiStatusLabels = {
  'running': 'Berjalan',
  'computed': 'Dihitung',
  'approved': 'Disetujui',
};

const kpiModuleLabels = {'CREW': 'Crew', 'LEADER': 'Leader'};

class KpiIndicatorResult {
  final String code;
  final String name;
  final String ruleType;
  final String kind;
  final String scope;
  final double? cap;

  /// Indikator kejadian: besar pengurangan/penambahan sesudah plafon.
  final double value;
  final double raw;
  final bool na;
  final int events;
  final double? actual;
  final double? target;

  const KpiIndicatorResult({
    required this.code,
    required this.name,
    this.ruleType = '',
    this.kind = '',
    this.scope = 'person',
    this.cap,
    this.value = 0,
    this.raw = 0,
    this.na = false,
    this.events = 0,
    this.actual,
    this.target,
  });

  factory KpiIndicatorResult.fromJson(Map<String, dynamic> j) => KpiIndicatorResult(
    code: '${j['code'] ?? ''}',
    name: '${j['name'] ?? ''}',
    ruleType: '${j['rule_type'] ?? ''}',
    kind: '${j['kind'] ?? ''}',
    scope: '${j['scope'] ?? 'person'}',
    cap: _numOrNull(j['cap']),
    value: _num(j['value']),
    raw: _num(j['raw']),
    na: _bool(j['na']),
    events: _int(j['events']),
    actual: _numOrNull(j['actual']),
    target: _numOrNull(j['target']),
  );
}

class KpiPoolResult {
  final String code;
  final String name;

  /// `deduct`, `achieve`, `direct`, `measure`, `bonus`.
  final String method;
  final double weight;
  final double score;
  final bool na;
  final List<KpiIndicatorResult> indicators;

  const KpiPoolResult({
    required this.code,
    required this.name,
    required this.method,
    required this.weight,
    required this.score,
    this.na = false,
    this.indicators = const [],
  });

  /// C8: pengurang langsung di luar bobot, masuk `penalty`.
  bool get isDirect => method == 'direct';

  factory KpiPoolResult.fromJson(Map<String, dynamic> j) => KpiPoolResult(
    code: '${j['code'] ?? ''}',
    name: '${j['name'] ?? ''}',
    method: '${j['method'] ?? ''}',
    weight: _num(j['weight']),
    score: _num(j['score']),
    na: _bool(j['na']),
    indicators: [for (final m in _maps(j['indicators'])) KpiIndicatorResult.fromJson(m)],
  );
}

class KpiModuleResult {
  final double earned;
  final double applicable;
  final double penalty;
  final double? score;
  final String predicate;
  final List<KpiPoolResult> pools;

  const KpiModuleResult({
    this.earned = 0,
    this.applicable = 0,
    this.penalty = 0,
    this.score,
    this.predicate = '',
    this.pools = const [],
  });

  factory KpiModuleResult.fromJson(Map<String, dynamic> j) => KpiModuleResult(
    earned: _num(j['earned']),
    applicable: _num(j['applicable']),
    penalty: _num(j['penalty']),
    score: _numOrNull(j['score']),
    predicate: '${j['predicate'] ?? ''}',
    pools: [for (final m in _maps(j['pools'])) KpiPoolResult.fromJson(m)],
  );
}

class KpiDispute {
  final int id;
  final int eventId;
  final String reason;
  final String? photoUrl;

  /// `open`, `accepted`, `rejected`.
  final String status;
  final String? decidedByName;
  final DateTime? decidedAt;
  final String? decisionNote;
  final DateTime? createdAt;

  const KpiDispute({
    required this.id,
    required this.eventId,
    required this.reason,
    required this.status,
    this.photoUrl,
    this.decidedByName,
    this.decidedAt,
    this.decisionNote,
    this.createdAt,
  });

  factory KpiDispute.fromJson(Map<String, dynamic> j) => KpiDispute(
    id: _int(j['id']),
    eventId: _int(j['event_id']),
    reason: '${j['reason'] ?? ''}',
    photoUrl: _str(j['photo_url']),
    status: '${j['status'] ?? ''}',
    decidedByName: _str(j['decided_by_name']),
    decidedAt: _time(j['decided_at']),
    decisionNote: _str(j['decision_note']),
    createdAt: _time(j['created_at']),
  );
}

const kpiDisputeLabels = {
  'open': 'Sanggahan diproses',
  'accepted': 'Sanggahan diterima',
  'rejected': 'Sanggahan ditolak',
};

const kpiEventStatusLabels = {
  'APPROVED': 'Berlaku',
  'PENDING': 'Menunggu',
  'REVERSED': 'Dibatalkan',
  'REJECTED': 'Ditolak',
};

class KpiEvent {
  final int id;
  final String module;
  final DateTime? occurredAt;
  final String branchName;
  final int? userId;
  final String indicatorCode;
  final String indicatorName;

  /// `person` atau `outlet` (kejadian outlet: `userId` kosong).
  final String scope;
  final String eventType;
  final double points;

  /// `AUTO`, `ACC`, `MANUAL`.
  final String source;

  /// `APPROVED`, `PENDING`, `REVERSED`, `REJECTED`.
  final String status;
  final String note;
  final String? evidenceUrl;
  final String? assessorName;
  final String? reverseReason;
  final KpiDispute? dispute;
  final bool canDispute;
  final DateTime? disputeUntil;

  const KpiEvent({
    required this.id,
    required this.indicatorCode,
    required this.indicatorName,
    required this.points,
    required this.status,
    this.module = 'CREW',
    this.occurredAt,
    this.branchName = '',
    this.userId,
    this.scope = 'person',
    this.eventType = '',
    this.source = '',
    this.note = '',
    this.evidenceUrl,
    this.assessorName,
    this.reverseReason,
    this.dispute,
    this.canDispute = false,
    this.disputeUntil,
  });

  bool get isOutlet => scope == 'outlet';
  bool get isCounted => status == 'APPROVED';

  factory KpiEvent.fromJson(Map<String, dynamic> j) => KpiEvent(
    id: _int(j['id']),
    module: '${j['module'] ?? 'CREW'}',
    occurredAt: _time(j['occurred_at']),
    branchName: '${j['branch_name'] ?? ''}',
    userId: _intOrNull(j['user_id']),
    indicatorCode: '${j['indicator_code'] ?? ''}',
    indicatorName: '${j['indicator_name'] ?? ''}',
    scope: '${j['scope'] ?? 'person'}',
    eventType: '${j['event_type'] ?? ''}',
    points: _num(j['points']),
    source: '${j['source'] ?? ''}',
    status: '${j['status'] ?? ''}',
    note: '${j['note'] ?? ''}',
    evidenceUrl: _str(j['evidence_url']),
    assessorName: _str(j['assessor_name']),
    reverseReason: _str(j['reverse_reason']),
    dispute: j['dispute'] is Map ? KpiDispute.fromJson(Map<String, dynamic>.from(j['dispute'] as Map)) : null,
    canDispute: _bool(j['can_dispute']),
    disputeUntil: _time(j['dispute_until']),
  );

  KpiEvent withDispute(KpiDispute d) => KpiEvent(
    id: id,
    module: module,
    occurredAt: occurredAt,
    branchName: branchName,
    userId: userId,
    indicatorCode: indicatorCode,
    indicatorName: indicatorName,
    scope: scope,
    eventType: eventType,
    points: points,
    source: source,
    status: status,
    note: note,
    evidenceUrl: evidenceUrl,
    assessorName: assessorName,
    reverseReason: reverseReason,
    dispute: d,
    canDispute: false,
    disputeUntil: disputeUntil,
  );
}

/// Skor satu orang di satu modul (`KPIScoreView`), dengan rincian & kejadian
/// bila dari `/me/kpi`.
class KpiScore {
  final String period;
  final String module;
  final int userId;
  final String name;
  final int branchId;
  final String branchName;

  /// Null = belum ada angka (semua pool N/A).
  final double? score;
  final String predicate;

  /// `running`, `computed`, `approved`.
  final String status;
  final KpiModuleResult? detail;
  final List<KpiEvent> events;

  const KpiScore({
    required this.period,
    required this.module,
    required this.userId,
    required this.name,
    this.branchId = 0,
    this.branchName = '',
    this.score,
    this.predicate = '',
    this.status = 'running',
    this.detail,
    this.events = const [],
  });

  factory KpiScore.fromJson(Map<String, dynamic> j) => KpiScore(
    period: '${j['period'] ?? ''}',
    module: '${j['module'] ?? ''}',
    userId: _int(j['user_id']),
    name: '${j['name'] ?? ''}',
    branchId: _int(j['branch_id']),
    branchName: '${j['branch_name'] ?? ''}',
    score: _numOrNull(j['score']),
    predicate: '${j['predicate'] ?? ''}',
    status: '${j['status'] ?? 'running'}',
    detail: j['detail'] is Map ? KpiModuleResult.fromJson(Map<String, dynamic>.from(j['detail'] as Map)) : null,
    events: [for (final m in _maps(j['events'])) KpiEvent.fromJson(m)],
  );

  KpiScore replaceEvent(KpiEvent e) => KpiScore(
    period: period,
    module: module,
    userId: userId,
    name: name,
    branchId: branchId,
    branchName: branchName,
    score: score,
    predicate: predicate,
    status: status,
    detail: detail,
    events: [for (final x in events) x.id == e.id ? e : x],
  );
}

/// `GET /me/kpi`.
class MyKpi {
  final String period;
  final DateTime? inputCloseAt;
  final List<KpiScore> scores;

  const MyKpi({required this.period, this.inputCloseAt, this.scores = const []});

  factory MyKpi.fromJson(Map<String, dynamic> j) => MyKpi(
    period: '${j['period'] ?? ''}',
    inputCloseAt: _time(j['input_close_at']),
    scores: [for (final m in _maps(j['scores'])) KpiScore.fromJson(m)],
  );
}

/// `GET /kpi/team` — leader, outlet yang dipimpinnya. Tanpa rincian.
class KpiTeam {
  final String period;
  final String branchName;
  final List<KpiScore> crew;
  final List<KpiScore> leaders;

  const KpiTeam({required this.period, this.branchName = '', this.crew = const [], this.leaders = const []});

  factory KpiTeam.fromJson(Map<String, dynamic> j) => KpiTeam(
    period: '${j['period'] ?? ''}',
    branchName: '${j['branch_name'] ?? ''}',
    crew: [for (final m in _maps(j['crew'])) KpiScore.fromJson(m)],
    leaders: [for (final m in _maps(j['leaders'])) KpiScore.fromJson(m)],
  );
}

/// KPI belum berlaku untuk periode itu (`409 kpi_not_active`).
class KpiNotActive implements Exception {
  final String message;
  KpiNotActive(this.message);
  @override
  String toString() => message;
}

// ---------------------------------------------------------------- ceklis foto

const checklistDutyLabels = {'cashier': 'Kasir', 'server': 'Penyaji'};
const checklistPhaseLabels = {'opening': 'Opening', 'closing': 'Closing'};

class ChecklistItemState {
  final int itemId;
  final String name;
  final String indicator;
  final bool allowUnused;

  /// `missing`, `pending`, `approved`, `rejected`.
  final String status;
  final int? photoId;
  final String? photoUrl;
  final bool unused;
  final String unusedReason;
  final DateTime? takenAt;
  final String? uploadedByName;
  final String rejectReason;
  final bool late;
  final bool canSubmit;

  const ChecklistItemState({
    required this.itemId,
    required this.name,
    required this.status,
    this.indicator = '',
    this.allowUnused = false,
    this.photoId,
    this.photoUrl,
    this.unused = false,
    this.unusedReason = '',
    this.takenAt,
    this.uploadedByName,
    this.rejectReason = '',
    this.late = false,
    this.canSubmit = false,
  });

  /// Sudah ada kiriman yang tidak ditolak (pending atau di-ACC).
  bool get isSent => status == 'pending' || status == 'approved';

  factory ChecklistItemState.fromJson(Map<String, dynamic> j) => ChecklistItemState(
    itemId: _int(j['item_id']),
    name: '${j['name'] ?? ''}',
    indicator: '${j['indicator'] ?? ''}',
    allowUnused: _bool(j['allow_unused']),
    status: '${j['status'] ?? 'missing'}',
    photoId: _intOrNull(j['photo_id']),
    photoUrl: _str(j['photo_url']),
    unused: _bool(j['unused']),
    unusedReason: '${j['unused_reason'] ?? ''}',
    takenAt: _time(j['taken_at']),
    uploadedByName: _str(j['uploaded_by_name']),
    rejectReason: '${j['reject_reason'] ?? ''}',
    late: _bool(j['late']),
    canSubmit: _bool(j['can_submit']),
  );
}

class ChecklistPhase {
  /// `opening` atau `closing`.
  final String phase;
  final DateTime? opensAt;

  /// Batas terlambat (opening saja).
  final DateTime? deadline;

  /// Batas kirim. Sesudahnya kiriman ditolak.
  final DateTime? cutoff;
  final bool open;
  final bool complete;
  final List<ChecklistItemState> items;

  const ChecklistPhase({
    required this.phase,
    this.opensAt,
    this.deadline,
    this.cutoff,
    this.open = false,
    this.complete = false,
    this.items = const [],
  });

  int get sentCount => items.where((i) => i.isSent).length;

  /// Fase terbuka pada [now]: dihitung dari jam buka & batas kirim, supaya
  /// data yang dimuat sebelum fase dibuka tetap benar sesudah jamnya lewat.
  /// Tanpa jam (tidak pernah terjadi di server sekarang) → `open` dari server.
  bool isOpenAt(DateTime now) {
    if (opensAt == null || cutoff == null) return open;
    return !now.isBefore(opensAt!) && now.isBefore(cutoff!);
  }

  /// Butir yang perlu dan bisa dikirim pada [now]: belum ada kiriman yang
  /// tidak ditolak, dan fasenya terbuka. Server tetap penentunya.
  List<ChecklistItemState> toSendAt(DateTime now) =>
      isOpenAt(now) ? [for (final i in items) if (!i.isSent) i] : const [];

  factory ChecklistPhase.fromJson(Map<String, dynamic> j) => ChecklistPhase(
    phase: '${j['phase'] ?? ''}',
    opensAt: _time(j['opens_at']),
    deadline: _time(j['deadline']),
    cutoff: _time(j['cutoff']),
    open: _bool(j['open']),
    complete: _bool(j['complete']),
    items: [for (final m in _maps(j['items'])) ChecklistItemState.fromJson(m)],
  );
}

/// Satu set ceklis: outlet × tanggal × kode shift × tugas.
class ChecklistSet {
  final int scheduleId;
  final String date;
  final int branchId;
  final String branchName;
  final String shiftName;

  /// `cashier` atau `server`.
  final String duty;

  /// Sudah dinilai KPI (tanggal mulai dinilai sudah diisi owner/SPV).
  final bool judged;
  final List<ChecklistPhase> phases;

  const ChecklistSet({
    required this.scheduleId,
    required this.date,
    required this.duty,
    this.branchId = 0,
    this.branchName = '',
    this.shiftName = '',
    this.judged = false,
    this.phases = const [],
  });

  ChecklistPhase? phaseOf(String phase) {
    for (final p in phases) {
      if (p.phase == phase) return p;
    }
    return null;
  }

  factory ChecklistSet.fromJson(Map<String, dynamic> j) => ChecklistSet(
    scheduleId: _int(j['schedule_id']),
    date: '${j['date'] ?? ''}',
    branchId: _int(j['branch_id']),
    branchName: '${j['branch_name'] ?? ''}',
    shiftName: '${j['shift_name'] ?? ''}',
    duty: '${j['duty'] ?? ''}',
    judged: _bool(j['judged']),
    phases: [for (final m in _maps(j['phases'])) ChecklistPhase.fromJson(m)],
  );
}

/// Ringkasan untuk kartu Beranda & pengingat Tutup Shift.
class ChecklistSummary {
  /// Butir yang bisa dikirim sekarang (fase terbuka, belum ada kiriman, atau
  /// ditolak).
  final int toSend;

  /// Dari [toSend], yang ditolak dan perlu dikirim ulang.
  final int rejected;
  final List<String> names;

  const ChecklistSummary({this.toSend = 0, this.rejected = 0, this.names = const []});

  factory ChecklistSummary.of(Iterable<ChecklistSet> sets, {required DateTime now, String? phase, int? branchId}) {
    var toSend = 0, rejected = 0;
    final names = <String>[];
    for (final s in sets) {
      if (branchId != null && s.branchId != branchId) continue;
      for (final p in s.phases) {
        if (phase != null && p.phase != phase) continue;
        for (final i in p.toSendAt(now)) {
          toSend++;
          if (i.status == 'rejected') rejected++;
          if (!names.contains(i.name)) names.add(i.name);
        }
      }
    }
    return ChecklistSummary(toSend: toSend, rejected: rejected, names: names);
  }
}

// ---------------------------------------------------------------- setoran

const cashDepositStatusLabels = {
  'pending': 'Menunggu verifikasi',
  'verified': 'Verified',
  'rejected': 'Ditolak',
};

class CashDeposit {
  final int id;
  final String branchName;

  /// `YYYY-MM-DD`.
  final String operationalDate;
  final String leaderName;
  final double amount;
  final String note;
  final String? photoUrl;
  final DateTime? uploadedAt;
  final DateTime? transferAt;

  /// `pending`, `verified`, `rejected`.
  final String status;
  final bool late;
  final String? verifiedByName;
  final DateTime? verifiedAt;
  final String? rejectedByName;
  final String rejectReason;

  const CashDeposit({
    required this.id,
    required this.operationalDate,
    required this.amount,
    required this.status,
    this.branchName = '',
    this.leaderName = '',
    this.note = '',
    this.photoUrl,
    this.uploadedAt,
    this.transferAt,
    this.late = false,
    this.verifiedByName,
    this.verifiedAt,
    this.rejectedByName,
    this.rejectReason = '',
  });

  factory CashDeposit.fromJson(Map<String, dynamic> j) => CashDeposit(
    id: _int(j['id']),
    branchName: '${j['branch_name'] ?? ''}',
    operationalDate: _ymd(j['operational_date']),
    leaderName: '${j['leader_name'] ?? ''}',
    amount: _num(j['amount']),
    note: '${j['note'] ?? ''}',
    photoUrl: _str(j['photo_url']),
    uploadedAt: _time(j['uploaded_at']),
    transferAt: _time(j['transfer_at']),
    status: '${j['status'] ?? ''}',
    late: _bool(j['late']),
    verifiedByName: _str(j['verified_by_name']),
    verifiedAt: _time(j['verified_at']),
    rejectedByName: _str(j['rejected_by_name']),
    rejectReason: '${j['reject_reason'] ?? ''}',
  );
}

// ---------------------------------------------------------------- sidak

const inspectionGroupLabels = {
  'L6.1A': 'Kebersihan area',
  'L6.1B': 'Peralatan operasional',
  'L6.1C': 'Peralatan kebersihan',
  'L6.1D': 'Fasilitas',
  'L6.3': 'Bahan baku',
  'info': 'Informasi (tanpa poin)',
};

/// Urutan tampil kelompok butir sidak.
const inspectionGroupOrder = ['L6.1A', 'L6.1B', 'L6.1C', 'L6.1D', 'L6.3', 'info'];

class InspectionItem {
  final int id;
  final String group;
  final String name;
  final int sort;
  final bool isActive;

  const InspectionItem({required this.id, required this.group, required this.name, this.sort = 0, this.isActive = true});

  factory InspectionItem.fromJson(Map<String, dynamic> j) => InspectionItem(
    id: _int(j['id']),
    group: '${j['group'] ?? ''}',
    name: '${j['name'] ?? ''}',
    sort: _int(j['sort']),
    isActive: j['is_active'] != false,
  );
}

class InspectionResult {
  final int itemId;
  final String group;
  final String itemName;
  final bool passed;
  final String note;
  final String? photoUrl;

  const InspectionResult({
    required this.itemId,
    required this.group,
    required this.itemName,
    required this.passed,
    this.note = '',
    this.photoUrl,
  });

  factory InspectionResult.fromJson(Map<String, dynamic> j) => InspectionResult(
    itemId: _int(j['item_id']),
    group: '${j['group'] ?? ''}',
    itemName: '${j['item_name'] ?? ''}',
    passed: _bool(j['passed']),
    note: '${j['note'] ?? ''}',
    photoUrl: _str(j['photo_url']),
  );
}

class Inspection {
  final int id;
  final int branchId;
  final String branchName;
  final String inspectorName;
  final DateTime? at;
  final double distanceMeters;
  final String? photoUrl;
  final String notes;
  final String followUp;

  /// Hanya sidak pertama outlet per minggu (Senin–Minggu) yang dinilai.
  final bool scored;
  final int failedCount;
  final List<InspectionResult> results;

  const Inspection({
    required this.id,
    required this.branchId,
    this.branchName = '',
    this.inspectorName = '',
    this.at,
    this.distanceMeters = 0,
    this.photoUrl,
    this.notes = '',
    this.followUp = '',
    this.scored = false,
    this.failedCount = 0,
    this.results = const [],
  });

  factory Inspection.fromJson(Map<String, dynamic> j) => Inspection(
    id: _int(j['id']),
    branchId: _int(j['branch_id']),
    branchName: '${j['branch_name'] ?? ''}',
    inspectorName: '${j['inspector_name'] ?? ''}',
    at: _time(j['at']),
    distanceMeters: _num(j['distance_meters']),
    photoUrl: _str(j['photo_url']),
    notes: '${j['notes'] ?? ''}',
    followUp: '${j['follow_up'] ?? ''}',
    scored: _bool(j['scored']),
    failedCount: _int(j['failed_count']),
    results: [for (final m in _maps(j['results'])) InspectionResult.fromJson(m)],
  );
}

/// Senin minggu [d] (WIB di HP), sebagai `YYYY-MM-DD`. Server memakai minggu
/// Senin–Minggu untuk "sidak pertama per minggu".
DateTime weekStartOf(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// Periode `YYYY-MM` dari tanggal.
String kpiPeriodOf(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
