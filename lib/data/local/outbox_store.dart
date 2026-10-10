import 'dart:math';

import 'package:sqflite/sqflite.dart';

/// Keadaan satu penjualan offline di antrean kirim.
abstract final class OutboxStatus {
  /// Belum sampai ke server. Selama masih ada yang begini, HP inilah
  /// satu-satunya yang tahu penjualan itu pernah terjadi.
  static const pending = 'pending';

  /// Sudah tercatat di server.
  static const sent = 'sent';

  /// Ditolak server sebagai permintaan rusak. Tidak dicoba lagi sendiri;
  /// menunggu ditangani orang.
  static const failed = 'failed';
}

/// Satu penjualan yang dibuat saat offline.
class OutboxEntry {
  final int id;
  final int branchId;
  final String idempotencyKey;

  /// Nomor nota yang sudah diberikan ke pembeli, mis. `OFF-20261010-0003`.
  final String clientRef;
  final DateTime occurredAt;
  final int total;

  /// Isi permintaan `POST /product-transactions/offline` (JSON).
  final String payload;

  /// Nota yang sudah diberikan ke pembeli (JSON bentuk struk server).
  final String receipt;
  final String status;
  final int attempts;
  final String? lastError;

  /// Nomor invoice resmi, terisi setelah terkirim.
  final String? invoiceNo;
  final DateTime? sentAt;

  const OutboxEntry({
    required this.id,
    required this.branchId,
    required this.idempotencyKey,
    required this.clientRef,
    required this.occurredAt,
    required this.total,
    required this.payload,
    required this.receipt,
    required this.status,
    this.attempts = 0,
    this.lastError,
    this.invoiceNo,
    this.sentAt,
  });

  bool get isPending => status == OutboxStatus.pending;
  bool get isSent => status == OutboxStatus.sent;
  bool get isFailed => status == OutboxStatus.failed;

  factory OutboxEntry.fromRow(Map<String, Object?> r) => OutboxEntry(
        id: r['id'] as int,
        branchId: r['branch_id'] as int,
        idempotencyKey: r['idempotency_key'] as String,
        clientRef: r['client_ref'] as String,
        occurredAt: DateTime.fromMillisecondsSinceEpoch(r['occurred_at'] as int),
        total: r['total'] as int,
        payload: r['payload'] as String,
        receipt: r['receipt'] as String,
        status: r['status'] as String,
        attempts: r['attempts'] as int,
        lastError: r['last_error'] as String?,
        invoiceNo: r['invoice_no'] as String?,
        sentAt: r['sent_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(r['sent_at'] as int),
      );
}

/// Nomor yang dipesan untuk satu penjualan offline sebelum notanya disusun.
class OfflineNumbers {
  /// Urutan nota hari itu di cabang ini, mulai dari 1.
  final int noteSeq;

  /// Nomor antrean lanjutan di shift ini.
  final int queueNo;

  const OfflineNumbers({required this.noteSeq, required this.queueNo});
}

/// Apa yang disimpan untuk satu penjualan offline.
class OutboxDraft {
  final String clientRef;
  final String payload;
  final String receipt;

  const OutboxDraft({required this.clientRef, required this.payload, required this.receipt});
}

/// Antrean kirim penjualan offline beserta catatan kecil milik perangkat.
///
/// Semuanya di satu DB supaya memesan nomor nota dan menyimpan penjualannya
/// bisa terjadi dalam satu transaksi: nota tidak pernah keluar untuk penjualan
/// yang belum tertulis.
class OutboxStore {
  final Future<Database> _db;

  OutboxStore(this._db);

  // ── penjualan ──────────────────────────────────────────────────────────

  /// Simpan satu penjualan offline.
  ///
  /// Nomor nota dan nomor antrean dipesan lebih dulu, lalu [build] menyusun
  /// isi permintaan dan notanya dengan nomor itu, lalu barisnya ditulis —
  /// semuanya satu transaksi. Idempotency key yang sudah ada mengembalikan
  /// baris yang sudah tersimpan tanpa memesan nomor baru, jadi menekan bayar
  /// dua kali tidak pernah menghasilkan dua penjualan.
  Future<OutboxEntry> record({
    required int branchId,
    required int shiftId,
    required String idempotencyKey,
    required DateTime occurredAt,
    required int total,
    required OutboxDraft Function(OfflineNumbers numbers) build,
  }) async {
    final db = await _db;
    return db.transaction((txn) async {
      final existing = await txn.query('outbox',
          where: 'idempotency_key = ?', whereArgs: [idempotencyKey], limit: 1);
      if (existing.isNotEmpty) return OutboxEntry.fromRow(existing.first);

      final noteSeq = await _increment(txn, _noteKey(branchId, occurredAt));
      final queueNo = await _increment(txn, _queueKey(shiftId));
      final draft = build(OfflineNumbers(noteSeq: noteSeq, queueNo: queueNo));

      final id = await txn.insert('outbox', {
        'branch_id': branchId,
        'idempotency_key': idempotencyKey,
        'client_ref': draft.clientRef,
        'occurred_at': occurredAt.millisecondsSinceEpoch,
        'total': total,
        'payload': draft.payload,
        'receipt': draft.receipt,
        'status': OutboxStatus.pending,
      });
      final row = await txn.query('outbox', where: 'id = ?', whereArgs: [id], limit: 1);
      return OutboxEntry.fromRow(row.first);
    });
  }

  /// Penjualan cabang ini yang belum terkirim, dari yang tertua.
  Future<List<OutboxEntry>> pending(int branchId) async {
    final db = await _db;
    final rows = await db.query('outbox',
        where: 'branch_id = ? AND status = ?',
        whereArgs: [branchId, OutboxStatus.pending],
        orderBy: 'id ASC');
    return rows.map(OutboxEntry.fromRow).toList();
  }

  /// Semua penjualan offline cabang ini, terbaru dulu.
  Future<List<OutboxEntry>> list(int branchId, {int limit = 200}) async {
    final db = await _db;
    final rows = await db.query('outbox',
        where: 'branch_id = ?', whereArgs: [branchId], orderBy: 'id DESC', limit: limit);
    return rows.map(OutboxEntry.fromRow).toList();
  }

  Future<OutboxEntry?> byClientRef(int branchId, String clientRef) async {
    final db = await _db;
    final rows = await db.query('outbox',
        where: 'branch_id = ? AND client_ref = ?', whereArgs: [branchId, clientRef], limit: 1);
    return rows.isEmpty ? null : OutboxEntry.fromRow(rows.first);
  }

  /// Jumlah per status untuk cabang ini.
  Future<({int pending, int failed})> counts(int branchId) async {
    final db = await _db;
    final rows = await db.rawQuery(
        'SELECT status, COUNT(*) AS n FROM outbox WHERE branch_id = ? GROUP BY status', [branchId]);
    var pending = 0, failed = 0;
    for (final r in rows) {
      if (r['status'] == OutboxStatus.pending) pending = r['n'] as int;
      if (r['status'] == OutboxStatus.failed) failed = r['n'] as int;
    }
    return (pending: pending, failed: failed);
  }

  /// Penjualan yang belum terkirim di cabang MANA PUN. Dipakai penahan yang
  /// berlaku untuk seluruh HP (logout, pasang pembaruan).
  Future<int> pendingAnywhere() async {
    final db = await _db;
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM outbox WHERE status = ?', [OutboxStatus.pending]);
    return rows.first['n'] as int;
  }

  Future<void> markSent(int id, {required String invoiceNo, required DateTime at}) async {
    final db = await _db;
    await db.update(
      'outbox',
      {
        'status': OutboxStatus.sent,
        'invoice_no': invoiceNo,
        'sent_at': at.millisecondsSinceEpoch,
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Server menolak permintaannya. Baris disisihkan supaya tidak menghalangi
  /// penjualan sesudahnya.
  Future<void> markFailed(int id, String error) async {
    final db = await _db;
    await db.rawUpdate(
        'UPDATE outbox SET status = ?, attempts = attempts + 1, last_error = ? WHERE id = ?',
        [OutboxStatus.failed, error, id]);
  }

  /// Percobaan kirim yang belum mendapat jawaban. Baris tetap menunggu.
  Future<void> noteAttempt(int id, String error) async {
    final db = await _db;
    await db.rawUpdate(
        'UPDATE outbox SET attempts = attempts + 1, last_error = ? WHERE id = ?', [error, id]);
  }

  /// Kembalikan penjualan yang ditolak ke antrean untuk dicoba lagi.
  Future<void> retry(int id) async {
    final db = await _db;
    await db.update('outbox', {'status': OutboxStatus.pending},
        where: 'id = ? AND status = ?', whereArgs: [id, OutboxStatus.failed]);
  }

  /// Buang penjualan yang sudah terkirim sebelum [before]. Yang belum terkirim
  /// dan yang ditolak tidak pernah ikut terbuang.
  Future<int> purgeSent(DateTime before) async {
    final db = await _db;
    return db.delete('outbox',
        where: 'status = ? AND sent_at < ?',
        whereArgs: [OutboxStatus.sent, before.millisecondsSinceEpoch]);
  }

  // ── catatan perangkat ──────────────────────────────────────────────────

  Future<String?> meta(String key) async {
    final db = await _db;
    final rows = await db.query('meta', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setMeta(String key, String value) async {
    final db = await _db;
    await db.insert('meta', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Id perangkat ini, dibuat sekali dan dipakai seterusnya.
  Future<String> deviceId() async {
    final existing = await meta(_deviceKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final rnd = Random.secure();
    final id = List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await setMeta(_deviceKey, id);
    return id;
  }

  /// Catat nomor antrean yang diberikan server di shift ini. Penghitung lokal
  /// hanya pernah maju, supaya nomor offline berikutnya melanjutkan yang
  /// terakhir dipanggil.
  Future<void> observeQueueNo(int shiftId, int queueNo) async {
    if (shiftId <= 0 || queueNo <= 0) return;
    final db = await _db;
    await db.transaction((txn) async {
      final current = await _read(txn, _queueKey(shiftId));
      if (queueNo > current) {
        await txn.insert('meta', {'key': _queueKey(shiftId), 'value': '$queueNo'},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Nomor antrean terakhir yang diketahui HP ini untuk sebuah shift.
  Future<int> lastQueueNo(int shiftId) async {
    final db = await _db;
    return _read(db, _queueKey(shiftId));
  }

  static const _deviceKey = 'device_id';

  static String _queueKey(int shiftId) => 'queue:$shiftId';

  static String _noteKey(int branchId, DateTime day) {
    final d = '${day.year.toString().padLeft(4, '0')}${day.month.toString().padLeft(2, '0')}'
        '${day.day.toString().padLeft(2, '0')}';
    return 'note:$branchId:$d';
  }

  static Future<int> _read(DatabaseExecutor db, String key) async {
    final rows = await db.query('meta', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? 0 : int.tryParse(rows.first['value'] as String) ?? 0;
  }

  static Future<int> _increment(Transaction txn, String key) async {
    final next = await _read(txn, key) + 1;
    await txn.insert('meta', {'key': key, 'value': '$next'},
        conflictAlgorithm: ConflictAlgorithm.replace);
    return next;
  }
}
