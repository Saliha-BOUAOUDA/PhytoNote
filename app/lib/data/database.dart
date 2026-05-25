import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const _dbFile = 'phytonote.db';
  static const _dbVersion = 7;

  static Database? _instance;

  static Future<Database> open() async {
    if (_instance != null) return _instance!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbFile);
    _instance = await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
    return _instance!;
  }

  static Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE calibrations (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        test_type TEXT NOT NULL,
        standard_id INTEGER,
        standard_code_snapshot TEXT,
        standard_compound TEXT NOT NULL,
        reagent_batch_number TEXT,
        date_created INTEGER NOT NULL,
        date_opened_flask INTEGER NOT NULL,
        alert_after_days INTEGER DEFAULT 60,
        replicates INTEGER NOT NULL DEFAULT 3,
        concentrations TEXT,
        control_do REAL,
        slope REAL,
        intercept REAL,
        r2 REAL,
        notes TEXT,
        last_used INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE calibration_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        calibration_id TEXT NOT NULL,
        concentration REAL NOT NULL,
        do_replicates TEXT,
        retained_for_fit INTEGER DEFAULT 1,
        FOREIGN KEY (calibration_id) REFERENCES calibrations(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        started_at INTEGER NOT NULL,
        completed_at INTEGER,
        status TEXT NOT NULL,
        plant_id INTEGER,
        plant_code_snapshot TEXT,
        plant_name_snapshot TEXT,
        extract_id INTEGER,
        extract_abbr_snapshot TEXT,
        extract_name_snapshot TEXT,
        test_type TEXT NOT NULL,
        calibration_id TEXT,
        replicates INTEGER NOT NULL DEFAULT 2,
        standard_id INTEGER,
        standard_code_snapshot TEXT,
        bacteria_id INTEGER,
        bacteria_code_snapshot TEXT,
        control_do_reference REAL,
        control_measurement REAL,
        control_measured_at INTEGER,
        extract_conc_mg_per_ml REAL,
        ic50_ug_per_ml REAL,
        ec50_ug_per_ml REAL,
        mg_eq_per_g REAL,
        cmi_ug_per_ml REAL,
        cmb_ug_per_ml REAL,
        notes TEXT,
        FOREIGN KEY (calibration_id) REFERENCES calibrations(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE measurements (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        concentration REAL NOT NULL,
        replicate_number INTEGER NOT NULL,
        raw_do REAL NOT NULL,
        measured_at INTEGER NOT NULL,
        well_role TEXT NOT NULL DEFAULT 'sample',
        observed_color TEXT,
        validation_status TEXT,
        validation_message TEXT,
        is_excluded INTEGER DEFAULT 0,
        exclusion_reason TEXT,
        FOREIGN KEY (session_id) REFERENCES sessions(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        old_value TEXT,
        new_value TEXT,
        timestamp INTEGER NOT NULL,
        reason TEXT
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_measurements_session ON measurements(session_id)');
    await db.execute('CREATE INDEX idx_sessions_status ON sessions(status)');
    await db.execute(
        'CREATE INDEX idx_calibrations_test ON calibrations(test_type)');

    await _createCatalogTables(db);
  }

  /// Schéma uniforme pour les 5 entités du catalogue.
  /// Tables vides à la création — l'utilisateur importe des Starter Packs ou
  /// crée chaque entrée à la main depuis l'écran Catalogue.
  static Future<void> _createCatalogTables(Database db) async {
    for (final table in const ['plants', 'extracts', 'standards', 'bacteria', 'enzymes']) {
      await db.execute('''
        CREATE TABLE $table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          custom_code TEXT,
          abbreviation TEXT NOT NULL,
          name TEXT NOT NULL,
          metadata TEXT NOT NULL DEFAULT '{}',
          is_archived INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await db.execute(
          'CREATE INDEX idx_${table}_abbr ON $table(abbreviation)');
      await db.execute(
          'CREATE INDEX idx_${table}_archived ON $table(is_archived)');
    }
  }

  /// Migration v6 (et antérieurs) → v7 : refonte totale du schéma catalogue,
  /// suppression du seed hardcodé, ajout de l'entité `extracts`, sessions
  /// référencent désormais les entités par FK + snapshots immuables.
  ///
  /// Politique : **clean break**. Les anciennes tables catalogue sont
  /// droppées. Les sessions/calibrations historiques sont également droppées
  /// car leurs codes de plante/échantillon/standard/bactérie ne sont plus
  /// résolvables. L'app est encore en phase test (v1.2.0), aucune donnée de
  /// production à préserver — décision tranchée 2026-05-08.
  static Future<void> _upgradeSchema(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 7) {
      await db.transaction((txn) async {
        // Wipe complet — clean break v7.
        for (final table in const [
          'plants',
          'standards',
          'bacteria',
          'enzymes',
          'measurements',
          'sessions',
          'calibration_points',
          'calibrations',
          'audit_log',
        ]) {
          await txn.execute('DROP TABLE IF EXISTS $table');
        }
      });
      // Recréer le schéma propre — appel hors transaction car _createSchema
      // crée des index nommés qui peuvent entrer en collision si une
      // transaction est encore ouverte.
      await _createSchema(db, newVersion);
    }
  }

  static Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }

  /// Helper : compte total d'entrées catalogue (tous statuts confondus).
  /// Utilisé par le boot pour détecter un catalogue vide → onboarding.
  static Future<int> countAllCatalogEntries() async {
    final db = await open();
    int total = 0;
    for (final table in const ['plants', 'extracts', 'standards', 'bacteria', 'enzymes']) {
      final res = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
      total += (res.first['c'] as int? ?? 0);
    }
    return total;
  }
}
