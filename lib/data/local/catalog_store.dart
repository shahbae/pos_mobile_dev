import 'package:sqflite/sqflite.dart';

/// Potret katalog sebagaimana tersimpan di HP: isi mentahnya, versi dari
/// server, kapan diunduh, dan nomor bentuk yang dipakai aplikasi saat menyimpan.
class StoredCatalog {
  /// Nomor bentuk isi ([posCatalogSchema] saat disimpan). Potret dengan nomor
  /// lain ditulis oleh versi aplikasi yang berbeda dan tidak boleh dibaca.
  final int schema;
  final String version;
  final DateTime fetchedAt;

  /// JSON isi katalog persis seperti dikirim server.
  final String payload;

  const StoredCatalog({
    required this.schema,
    required this.version,
    required this.fetchedAt,
    required this.payload,
  });
}

/// Tempat potret katalog disimpan, satu per cabang.
abstract class CatalogStore {
  Future<StoredCatalog?> read(int branchId);

  /// Ganti potret cabang ini. Harus sekali jadi: pembaca tidak boleh pernah
  /// melihat potret setengah tertulis.
  Future<void> write(int branchId, StoredCatalog catalog);

  Future<void> delete(int branchId);
}

class SqfliteCatalogStore implements CatalogStore {
  final Future<Database> _db;

  SqfliteCatalogStore(this._db);

  @override
  Future<StoredCatalog?> read(int branchId) async {
    final db = await _db;
    final rows = await db.query('catalog', where: 'branch_id = ?', whereArgs: [branchId], limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return StoredCatalog(
      schema: row['schema'] as int,
      version: row['version'] as String,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(row['fetched_at'] as int),
      payload: row['payload'] as String,
    );
  }

  @override
  Future<void> write(int branchId, StoredCatalog catalog) async {
    final db = await _db;
    // Satu pernyataan = satu transaksi SQLite: potret lama tetap utuh sampai
    // yang baru selesai ditulis.
    await db.insert(
      'catalog',
      {
        'branch_id': branchId,
        'schema': catalog.schema,
        'version': catalog.version,
        'fetched_at': catalog.fetchedAt.millisecondsSinceEpoch,
        'payload': catalog.payload,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(int branchId) async {
    final db = await _db;
    await db.delete('catalog', where: 'branch_id = ?', whereArgs: [branchId]);
  }
}
