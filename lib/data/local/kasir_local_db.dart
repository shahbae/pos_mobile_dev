import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Versi skema DB lokal kasir. Naikkan tiap ada tabel/kolom baru, dan tambahkan
/// langkahnya di [_upgrade] — DB di HP kasir tidak pernah dibuat ulang.
const kasirLocalDbVersion = 2;

const _fileName = 'kasir_local.db';

/// Buka DB lokal kasir.
///
/// [factory] dan [path] hanya diisi oleh tes (SQLite di memori); aplikasi
/// memakai bawaan sqflite dan berkas di folder database aplikasi.
Future<Database> openKasirLocalDb({DatabaseFactory? factory, String? path}) async {
  final f = factory ?? databaseFactory;
  final dbPath = path ?? p.join(await f.getDatabasesPath(), _fileName);
  return f.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: kasirLocalDbVersion,
      onCreate: (db, version) => _upgrade(db, 0, version),
      onUpgrade: _upgrade,
    ),
  );
}

/// Bawa skema dari [from] ke [to], satu versi tiap langkah.
Future<void> _upgrade(Database db, int from, int to) async {
  if (from < 1) {
    // Satu baris per cabang: potret katalog terakhir yang berhasil dibaca utuh.
    // `payload` adalah JSON isi katalog persis seperti dikirim server.
    await db.execute('''
      CREATE TABLE catalog (
        branch_id  INTEGER PRIMARY KEY,
        schema     INTEGER NOT NULL,
        version    TEXT    NOT NULL,
        fetched_at INTEGER NOT NULL,
        payload    TEXT    NOT NULL
      )
    ''');
  }
  if (from < 2) {
    // Penjualan yang dibuat saat offline dan belum (atau sudah) terkirim.
    // Baris tidak pernah dihapus sebelum server menjawab: sampai saat itu
    // inilah satu-satunya catatan penjualannya.
    //
    // `payload` adalah isi permintaan ke server, `receipt` nota yang sudah
    // diberikan ke pembeli. Keduanya dibekukan saat penjualan terjadi.
    await db.execute('''
      CREATE TABLE outbox (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id       INTEGER NOT NULL,
        idempotency_key TEXT    NOT NULL UNIQUE,
        client_ref      TEXT    NOT NULL,
        occurred_at     INTEGER NOT NULL,
        total           INTEGER NOT NULL,
        payload         TEXT    NOT NULL,
        receipt         TEXT    NOT NULL,
        status          TEXT    NOT NULL,
        attempts        INTEGER NOT NULL DEFAULT 0,
        last_error      TEXT,
        invoice_no      TEXT,
        sent_at         INTEGER
      )
    ''');
    await db.execute('CREATE INDEX idx_outbox_branch_status ON outbox (branch_id, status, id)');
    // Catatan kecil milik perangkat: id perangkat, penghitung nomor nota dan
    // antrean, selisih jam server, shift dan kasir terakhir yang diketahui.
    await db.execute('''
      CREATE TABLE meta (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }
}
