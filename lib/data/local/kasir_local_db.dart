import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Versi skema DB lokal kasir. Naikkan tiap ada tabel/kolom baru, dan tambahkan
/// langkahnya di [_upgrade] — DB di HP kasir tidak pernah dibuat ulang.
const kasirLocalDbVersion = 1;

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
}
