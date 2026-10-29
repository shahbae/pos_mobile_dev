/// Reminder & permintaan pengecekan foto milik penerima (Tahap 4, F11).
/// Kontrak: be-pos `docs/api-reminder-fe.md`, bagian "App kasir".

DateTime? _time(dynamic v) => v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

class ReminderPhoto {
  final int id;
  final String url;
  final DateTime? receivedAt;

  /// `clean`, `dirty`, atau null bila belum dinilai.
  final String? verdict;

  const ReminderPhoto({required this.id, required this.url, this.receivedAt, this.verdict});

  bool get judged => verdict != null;

  factory ReminderPhoto.fromJson(Map<String, dynamic> j) => ReminderPhoto(
    id: (j['id'] as num?)?.toInt() ?? 0,
    url: '${j['url'] ?? ''}',
    receivedAt: _time(j['received_at']),
    verdict: j['verdict'] as String?,
  );
}

class ReminderPart {
  /// Id bagian kiriman — yang dikirim sebagai `part_id` saat mengunggah.
  final int id;
  final String name;

  /// `cashier` atau `server`.
  final String duty;
  final ReminderPhoto? photo;

  const ReminderPart({required this.id, required this.name, required this.duty, this.photo});

  factory ReminderPart.fromJson(Map<String, dynamic> j) => ReminderPart(
    id: (j['id'] as num?)?.toInt() ?? 0,
    name: '${j['name'] ?? ''}',
    duty: '${j['duty'] ?? ''}',
    photo: j['photo'] is Map ? ReminderPhoto.fromJson(Map<String, dynamic>.from(j['photo'])) : null,
  );
}

class MyReminder {
  final int id;

  /// `note` (catatan) atau `check` (pengecekan foto).
  final String kind;
  final String message;
  final String senderName;
  final DateTime? createdAt;
  final String branchName;

  /// `pending`, `read`, `replied`, `incomplete`, `missed`. Selalu status saat
  /// ini: begitu tenggat lewat, server langsung menjawab `incomplete`/`missed`.
  final String status;
  final int? deadlineMinutes;
  final DateTime? deadlineAt;
  final DateTime? openedAt;
  final DateTime? readAt;
  final DateTime? repliedAt;
  final List<ReminderPart> parts;

  /// Jam server saat jawaban dibuat. Hitung mundur memakai
  /// `deadlineAt − serverTime`, bukan jam HP yang bisa saja salah.
  final DateTime? serverTime;

  const MyReminder({
    required this.id,
    required this.kind,
    required this.message,
    required this.senderName,
    required this.branchName,
    required this.status,
    required this.parts,
    this.createdAt,
    this.deadlineMinutes,
    this.deadlineAt,
    this.openedAt,
    this.readAt,
    this.repliedAt,
    this.serverTime,
  });

  bool get isCheck => kind == 'check';
  bool get isPending => status == 'pending';
  int get photographed => parts.where((p) => p.photo != null).length;

  factory MyReminder.fromJson(Map<String, dynamic> j, {DateTime? serverTime}) => MyReminder(
    id: (j['id'] as num?)?.toInt() ?? 0,
    kind: '${j['kind'] ?? ''}',
    message: '${j['message'] ?? ''}',
    senderName: '${j['sender_name'] ?? ''}',
    createdAt: _time(j['created_at']),
    branchName: '${j['branch_name'] ?? ''}',
    status: '${j['status'] ?? 'pending'}',
    deadlineMinutes: (j['deadline_minutes'] as num?)?.toInt(),
    deadlineAt: _time(j['deadline_at']),
    openedAt: _time(j['opened_at']),
    readAt: _time(j['read_at']),
    repliedAt: _time(j['replied_at']),
    parts: [
      for (final p in (j['parts'] as List? ?? const []))
        if (p is Map) ReminderPart.fromJson(Map<String, dynamic>.from(p)),
    ],
    serverTime: _time(j['server_time']) ?? serverTime,
  );
}

class MyReminderPage {
  final List<MyReminder> items;
  final int total;
  final DateTime? serverTime;
  const MyReminderPage({required this.items, required this.total, this.serverTime});

  factory MyReminderPage.fromJson(Map<String, dynamic> j) {
    final server = _time(j['server_time']);
    return MyReminderPage(
      serverTime: server,
      total: (j['total'] as num?)?.toInt() ?? 0,
      items: [
        for (final e in (j['items'] as List? ?? const []))
          if (e is Map) MyReminder.fromJson(Map<String, dynamic>.from(e), serverTime: server),
      ],
    );
  }
}

const reminderStatusLabels = {
  'pending': 'Belum dibalas',
  'read': 'Sudah dibaca',
  'replied': 'Sudah dibalas',
  'incomplete': 'Kurang',
  'missed': 'Tidak dibalas',
};
