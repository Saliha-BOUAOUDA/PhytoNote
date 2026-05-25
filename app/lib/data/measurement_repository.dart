import 'package:sqflite/sqflite.dart';

import 'database.dart';
import 'models.dart';

class MeasurementRepository {
  static String idFor(
    String sessionId,
    double concentration,
    int replicateNumber, {
    String wellRole = 'sample',
  }) =>
      '$sessionId|${concentration.toStringAsFixed(6)}|$replicateNumber|$wellRole';

  Future<void> upsert(Measurement m) async {
    final db = await AppDatabase.open();
    await db.insert(
      'measurements',
      m.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Measurement>> bySession(String sessionId) async {
    final db = await AppDatabase.open();
    final rows = await db.query(
      'measurements',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'concentration DESC, replicate_number ASC',
    );
    return rows.map(Measurement.fromMap).toList();
  }

  Future<int> count(String sessionId) async {
    final db = await AppDatabase.open();
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM measurements WHERE session_id = ?',
      [sessionId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
