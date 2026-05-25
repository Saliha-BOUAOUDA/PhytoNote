import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'database.dart';
import 'models.dart';

class CalibrationRepository {
  Future<int> count() async {
    final db = await AppDatabase.open();
    final result = await db.rawQuery('SELECT COUNT(*) AS n FROM calibrations');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> validCount() async {
    final db = await AppDatabase.open();
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM calibrations WHERE r2 >= 0.97',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Calibration>> all({String? testTypeFilter}) async {
    final db = await AppDatabase.open();
    final rows = testTypeFilter == null
        ? await db.query('calibrations', orderBy: 'date_created DESC')
        : await db.query(
            'calibrations',
            where: 'test_type = ?',
            whereArgs: [testTypeFilter],
            orderBy: 'date_created DESC',
          );
    return rows.map(Calibration.fromMap).toList();
  }

  Future<Calibration?> byId(String id) async {
    final db = await AppDatabase.open();
    final rows = await db.query(
      'calibrations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Calibration.fromMap(rows.first);
  }

  Future<void> insert(Calibration c) async {
    final db = await AppDatabase.open();
    await db.insert(
      'calibrations',
      c.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Calibration c) async {
    final db = await AppDatabase.open();
    await db.update(
      'calibrations',
      c.toMap(),
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  Future<void> deleteById(String id) async {
    final db = await AppDatabase.open();
    await db.delete('calibration_points', where: 'calibration_id = ?', whereArgs: [id]);
    await db.delete('calibrations', where: 'id = ?', whereArgs: [id]);
  }

  /// Renvoie la calibration la plus récente avec R² ≥ 0.97 et non expirée
  /// pour ce couple (test, standard). Sinon `null`.
  Future<Calibration?> latestValidFor({
    required String testType,
    required String standardCode,
  }) async {
    final db = await AppDatabase.open();
    final rows = await db.query(
      'calibrations',
      where: 'test_type = ? AND standard_compound = ? AND r2 >= 0.97',
      whereArgs: [testType, standardCode],
      orderBy: 'date_created DESC',
    );
    for (final row in rows) {
      final cal = Calibration.fromMap(row);
      if (!cal.isExpired) return cal;
    }
    return null;
  }

  Future<List<CalibrationPoint>> pointsFor(String calibrationId) async {
    final db = await AppDatabase.open();
    final rows = await db.query(
      'calibration_points',
      where: 'calibration_id = ?',
      whereArgs: [calibrationId],
      orderBy: 'concentration ASC',
    );
    return rows.map((row) => CalibrationPoint(
          id: row['id'] as int?,
          calibrationId: row['calibration_id'] as String,
          concentration: (row['concentration'] as num).toDouble(),
          doReplicates: _decodeReplicates(row['do_replicates'] as String?),
          retainedForFit: (row['retained_for_fit'] as int? ?? 1) == 1,
        )).toList();
  }

  Future<void> upsertPoint(CalibrationPoint p) async {
    final db = await AppDatabase.open();
    await db.delete(
      'calibration_points',
      where: 'calibration_id = ? AND concentration = ?',
      whereArgs: [p.calibrationId, p.concentration],
    );
    await db.insert('calibration_points', {
      'calibration_id': p.calibrationId,
      'concentration': p.concentration,
      'do_replicates': jsonEncode(p.doReplicates),
      'retained_for_fit': p.retainedForFit ? 1 : 0,
    });
  }

  static List<double?> _decodeReplicates(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final list = jsonDecode(raw);
    if (list is! List) return const [];
    return list.map((e) => e == null ? null : (e as num).toDouble()).toList();
  }
}
