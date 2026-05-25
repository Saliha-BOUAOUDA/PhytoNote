import 'package:sqflite/sqflite.dart';

import 'catalog_models.dart';
import 'database.dart';

/// CRUD unifié pour les 5 entités du catalogue (plants, extracts, standards,
/// bacteria, enzymes). Toutes utilisent le même schéma : id INTEGER PK,
/// custom_code TEXT, abbreviation TEXT, name TEXT, metadata TEXT JSON.
class CatalogRepository {
  Future<Database> get _db async => AppDatabase.open();

  // ---------- Plants ----------
  Future<List<Plant>> listPlants({bool includeArchived = false}) async {
    final db = await _db;
    final rows = await db.query(
      'plants',
      where: includeArchived ? null : 'is_archived = 0',
      orderBy: 'abbreviation COLLATE NOCASE',
    );
    return rows.map(Plant.fromMap).toList();
  }

  Future<Plant?> findPlant(int id) async {
    final db = await _db;
    final rows = await db.query('plants', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Plant.fromMap(rows.first);
  }

  Future<Plant?> findPlantByAbbreviation(String abbr) async {
    final db = await _db;
    final rows = await db.query('plants',
        where: 'abbreviation = ?', whereArgs: [abbr], limit: 1);
    if (rows.isEmpty) return null;
    return Plant.fromMap(rows.first);
  }

  Future<int> upsertPlant(Plant p) async => _upsert('plants', p.toMap(), p.id);

  Future<void> archivePlant(int id, {bool archived = true}) =>
      _archive('plants', id, archived);

  Future<void> deletePlant(int id) => _hardDelete('plants', id);

  // ---------- Extracts ----------
  Future<List<Extract>> listExtracts({bool includeArchived = false}) async {
    final db = await _db;
    final rows = await db.query(
      'extracts',
      where: includeArchived ? null : 'is_archived = 0',
      orderBy: 'abbreviation COLLATE NOCASE',
    );
    return rows.map(Extract.fromMap).toList();
  }

  Future<Extract?> findExtract(int id) async {
    final db = await _db;
    final rows = await db.query('extracts', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Extract.fromMap(rows.first);
  }

  Future<Extract?> findExtractByAbbreviation(String abbr) async {
    final db = await _db;
    final rows = await db.query('extracts',
        where: 'abbreviation = ?', whereArgs: [abbr], limit: 1);
    if (rows.isEmpty) return null;
    return Extract.fromMap(rows.first);
  }

  Future<int> upsertExtract(Extract e) => _upsert('extracts', e.toMap(), e.id);

  Future<void> archiveExtract(int id, {bool archived = true}) =>
      _archive('extracts', id, archived);

  Future<void> deleteExtract(int id) => _hardDelete('extracts', id);

  // ---------- Standards ----------
  Future<List<Standard>> listStandards({bool includeArchived = false}) async {
    final db = await _db;
    final rows = await db.query(
      'standards',
      where: includeArchived ? null : 'is_archived = 0',
      orderBy: 'abbreviation COLLATE NOCASE',
    );
    return rows.map(Standard.fromMap).toList();
  }

  Future<Standard?> findStandard(int id) async {
    final db = await _db;
    final rows = await db.query('standards', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Standard.fromMap(rows.first);
  }

  Future<Standard?> findStandardByAbbreviation(String abbr) async {
    final db = await _db;
    final rows = await db.query('standards',
        where: 'abbreviation = ?', whereArgs: [abbr], limit: 1);
    if (rows.isEmpty) return null;
    return Standard.fromMap(rows.first);
  }

  Future<int> upsertStandard(Standard s) =>
      _upsert('standards', s.toMap(), s.id);

  Future<void> archiveStandard(int id, {bool archived = true}) =>
      _archive('standards', id, archived);

  Future<void> deleteStandard(int id) => _hardDelete('standards', id);

  // ---------- Bacteria ----------
  Future<List<Bacteria>> listBacteria({bool includeArchived = false}) async {
    final db = await _db;
    final rows = await db.query(
      'bacteria',
      where: includeArchived ? null : 'is_archived = 0',
      orderBy: 'abbreviation COLLATE NOCASE',
    );
    return rows.map(Bacteria.fromMap).toList();
  }

  Future<Bacteria?> findBacteria(int id) async {
    final db = await _db;
    final rows = await db.query('bacteria', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Bacteria.fromMap(rows.first);
  }

  Future<Bacteria?> findBacteriaByAbbreviation(String abbr) async {
    final db = await _db;
    final rows = await db.query('bacteria',
        where: 'abbreviation = ?', whereArgs: [abbr], limit: 1);
    if (rows.isEmpty) return null;
    return Bacteria.fromMap(rows.first);
  }

  Future<int> upsertBacteria(Bacteria b) =>
      _upsert('bacteria', b.toMap(), b.id);

  Future<void> archiveBacteria(int id, {bool archived = true}) =>
      _archive('bacteria', id, archived);

  Future<void> deleteBacteria(int id) => _hardDelete('bacteria', id);

  // ---------- Enzymes ----------
  Future<List<Enzyme>> listEnzymes({bool includeArchived = false}) async {
    final db = await _db;
    final rows = await db.query(
      'enzymes',
      where: includeArchived ? null : 'is_archived = 0',
      orderBy: 'abbreviation COLLATE NOCASE',
    );
    return rows.map(Enzyme.fromMap).toList();
  }

  Future<Enzyme?> findEnzyme(int id) async {
    final db = await _db;
    final rows = await db.query('enzymes', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Enzyme.fromMap(rows.first);
  }

  Future<Enzyme?> findEnzymeByAbbreviation(String abbr) async {
    final db = await _db;
    final rows = await db.query('enzymes',
        where: 'abbreviation = ?', whereArgs: [abbr], limit: 1);
    if (rows.isEmpty) return null;
    return Enzyme.fromMap(rows.first);
  }

  Future<int> upsertEnzyme(Enzyme e) => _upsert('enzymes', e.toMap(), e.id);

  Future<void> archiveEnzyme(int id, {bool archived = true}) =>
      _archive('enzymes', id, archived);

  Future<void> deleteEnzyme(int id) => _hardDelete('enzymes', id);

  // ---------- Helpers internes ----------
  Future<int> _upsert(String table, Map<String, Object?> map, int? existingId) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (existingId == null) {
      final row = {
        ...map,
        'created_at': now,
        'updated_at': now,
      }..remove('id');
      return db.insert(table, row);
    } else {
      await db.update(
        table,
        {...map, 'updated_at': now}..remove('id'),
        where: 'id = ?',
        whereArgs: [existingId],
      );
      return existingId;
    }
  }

  Future<void> _archive(String table, int id, bool archived) async {
    final db = await _db;
    await db.update(
      table,
      {
        'is_archived': archived ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _hardDelete(String table, int id) async {
    final db = await _db;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }
}
