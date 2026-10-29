/// Tiket bantuan leader (Tahap 4, F12). Kontrak: be-pos
/// `docs/api-help-ticket-fe.md`.

DateTime? _time(dynamic v) => v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
String? _str(dynamic v) => v is String && v.isNotEmpty ? v : null;

class HelpCategory {
  final int id;
  final String name;
  const HelpCategory({required this.id, required this.name});

  factory HelpCategory.fromJson(Map<String, dynamic> j) =>
      HelpCategory(id: (j['id'] as num?)?.toInt() ?? 0, name: '${j['name'] ?? ''}');
}

class HelpTicketEvent {
  final String fromStatus;
  final String toStatus;

  /// Kosong = sistem (konfirmasi otomatis).
  final String? actorName;
  final String? note;
  final String? photoUrl;
  final DateTime? dueAt;
  final DateTime? createdAt;

  const HelpTicketEvent({
    required this.fromStatus,
    required this.toStatus,
    this.actorName,
    this.note,
    this.photoUrl,
    this.dueAt,
    this.createdAt,
  });

  factory HelpTicketEvent.fromJson(Map<String, dynamic> j) => HelpTicketEvent(
    fromStatus: '${j['from_status'] ?? ''}',
    toStatus: '${j['to_status'] ?? ''}',
    actorName: j['actor_id'] == null ? null : _str(j['actor_name']),
    note: _str(j['note']),
    photoUrl: _str(j['photo_url']),
    dueAt: _time(j['due_at']),
    createdAt: _time(j['created_at']),
  );
}

class HelpTicket {
  final int id;
  final String branchName;
  final String createdByName;

  /// `supervisor` atau `finance`.
  final String target;
  final String categoryName;
  final String description;
  final String? photoUrl;

  /// `submitted`, `rejected`, `approved`, `resolved`, `confirmed`.
  final String status;
  final DateTime? dueAt;
  final String? rejectReason;
  final String? rejectedByName;
  final String? approvedByName;
  final DateTime? resolvedAt;
  final String? resolvedByName;
  final String? resolutionNote;
  final String? resolutionPhotoUrl;
  final int reopenCount;
  final DateTime? confirmedAt;
  final bool autoConfirmed;
  final DateTime? autoConfirmAt;

  /// Masih dikerjakan dan tenggatnya sudah lewat.
  final bool overdue;

  /// Tanda selesai terakhir lewat tenggat; null sampai ditandai selesai.
  final bool? late;

  /// Tombol yang boleh tampil untuk pemanggil (`reopen`, `confirm`, …).
  final List<String> actions;
  final DateTime? createdAt;
  final List<HelpTicketEvent> events;

  const HelpTicket({
    required this.id,
    required this.branchName,
    required this.createdByName,
    required this.target,
    required this.categoryName,
    required this.description,
    required this.status,
    required this.reopenCount,
    required this.autoConfirmed,
    required this.overdue,
    required this.actions,
    required this.events,
    this.photoUrl,
    this.dueAt,
    this.rejectReason,
    this.rejectedByName,
    this.approvedByName,
    this.resolvedAt,
    this.resolvedByName,
    this.resolutionNote,
    this.resolutionPhotoUrl,
    this.confirmedAt,
    this.autoConfirmAt,
    this.late,
    this.createdAt,
  });

  bool can(String action) => actions.contains(action);

  factory HelpTicket.fromJson(Map<String, dynamic> j) => HelpTicket(
    id: (j['id'] as num?)?.toInt() ?? 0,
    branchName: '${j['branch_name'] ?? ''}',
    createdByName: '${j['created_by_name'] ?? ''}',
    target: '${j['target'] ?? ''}',
    categoryName: '${j['category_name'] ?? ''}',
    description: '${j['description'] ?? ''}',
    photoUrl: _str(j['photo_url']),
    status: '${j['status'] ?? ''}',
    dueAt: _time(j['due_at']),
    rejectReason: _str(j['reject_reason']),
    rejectedByName: _str(j['rejected_by_name']),
    approvedByName: _str(j['approved_by_name']),
    resolvedAt: _time(j['resolved_at']),
    resolvedByName: _str(j['resolved_by_name']),
    resolutionNote: _str(j['resolution_note']),
    resolutionPhotoUrl: _str(j['resolution_photo_url']),
    reopenCount: (j['reopen_count'] as num?)?.toInt() ?? 0,
    confirmedAt: _time(j['confirmed_at']),
    autoConfirmed: j['auto_confirmed'] == true,
    autoConfirmAt: _time(j['auto_confirm_at']),
    overdue: j['overdue'] == true,
    late: j['late'] as bool?,
    actions: [for (final a in (j['actions'] as List? ?? const [])) '$a'],
    createdAt: _time(j['created_at']),
    events: [
      for (final e in (j['events'] as List? ?? const []))
        if (e is Map) HelpTicketEvent.fromJson(Map<String, dynamic>.from(e)),
    ],
  );
}

const helpStatusLabels = {
  'submitted': 'Diajukan',
  'rejected': 'Ditolak',
  'approved': 'Disetujui',
  'resolved': 'Ditandai selesai',
  'confirmed': 'Dikonfirmasi',
};

const helpTargetLabels = {'supervisor': 'SPV', 'finance': 'Finance'};
