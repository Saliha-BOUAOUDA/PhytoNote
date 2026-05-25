import 'package:sqflite/sqflite.dart';

import 'database.dart';
import 'models.dart';

class SessionRepository {
  Future<void> insert(Session session) async {
    final db = await AppDatabase.open();
    await db.insert(
      'sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Session session) async {
    final db = await AppDatabase.open();
    await db.update(
      'sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<Session?> byId(String id) async {
    final db = await AppDatabase.open();
    final rows = await db.query(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Session.fromMap(rows.first);
  }

  Future<List<Session>> all({String? statusFilter}) async {
    final db = await AppDatabase.open();
    final rows = statusFilter == null
        ? await db.query('sessions', orderBy: 'started_at DESC')
        : await db.query(
            'sessions',
            where: 'status = ?',
            whereArgs: [statusFilter],
            orderBy: 'started_at DESC',
          );
    return rows.map(Session.fromMap).toList();
  }

  Future<int> count({String? statusFilter}) async {
    final db = await AppDatabase.open();
    final result = statusFilter == null
        ? await db.rawQuery('SELECT COUNT(*) AS n FROM sessions')
        : await db.rawQuery(
            'SELECT COUNT(*) AS n FROM sessions WHERE status = ?',
            [statusFilter],
          );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> setControlMeasurement(String sessionId, double value) async {
    final db = await AppDatabase.open();
    await db.update(
      'sessions',
      {
        'control_measurement': value,
        'control_measured_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> markCompleted(String sessionId) async {
    final db = await AppDatabase.open();
    await db.update(
      'sessions',
      {
        'status': 'completed',
        'completed_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> deleteById(String sessionId) async {
    final db = await AppDatabase.open();
    await db.delete('measurements', where: 'session_id = ?', whereArgs: [sessionId]);
    await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
  }
}

