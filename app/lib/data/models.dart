/// Modèles métier de session/mesure/calibration.
///
/// **v7 :** les sessions référencent les entités du catalogue par FK INTEGER
/// (`plantId`, `extractId`, `standardId`, `bacteriaId`) tout en stockant des
/// **snapshots immuables** des codes/noms au moment de la création de la
/// session. Cela garantit la traçabilité même si un utilisateur renomme une
/// entrée dans le catalogue après-coup.
library;

class Session {
  final String id;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String status;

  // Plante
  final int? plantId;
  final String? plantCodeSnapshot;
  final String? plantNameSnapshot;

  // Extrait (anciennement sampleType HE/EXT)
  final int? extractId;
  final String? extractAbbrSnapshot;
  final String? extractNameSnapshot;

  final String testType;
  final String? calibrationId;
  final int replicates;

  // Standard
  final int? standardId;
  final String? standardCodeSnapshot;

  final double? controlDOReference;
  final double? controlMeasurement;
  final DateTime? controlMeasuredAt;

  // Bactérie (antibac)
  final int? bacteriaId;
  final String? bacteriaCodeSnapshot;

  final double? extractConcentrationMgPerMl;
  final double? ic50UgPerMl;
  final double? ec50UgPerMl;
  final double? mgEquivalentPerG;
  final double? cmiUgPerMl;
  final double? cmbUgPerMl;
  final String? notes;

  const Session({
    required this.id,
    required this.startedAt,
    this.completedAt,
    required this.status,
    this.plantId,
    this.plantCodeSnapshot,
    this.plantNameSnapshot,
    this.extractId,
    this.extractAbbrSnapshot,
    this.extractNameSnapshot,
    required this.testType,
    this.calibrationId,
    this.replicates = 2,
    this.standardId,
    this.standardCodeSnapshot,
    this.controlDOReference,
    this.controlMeasurement,
    this.controlMeasuredAt,
    this.bacteriaId,
    this.bacteriaCodeSnapshot,
    this.extractConcentrationMgPerMl,
    this.ic50UgPerMl,
    this.ec50UgPerMl,
    this.mgEquivalentPerG,
    this.cmiUgPerMl,
    this.cmbUgPerMl,
    this.notes,
  });

  Session copyWith({
    DateTime? completedAt,
    String? status,
    double? controlMeasurement,
    DateTime? controlMeasuredAt,
    double? ic50UgPerMl,
    double? ec50UgPerMl,
    double? mgEquivalentPerG,
    double? cmiUgPerMl,
    double? cmbUgPerMl,
    String? notes,
  }) =>
      Session(
        id: id,
        startedAt: startedAt,
        completedAt: completedAt ?? this.completedAt,
        status: status ?? this.status,
        plantId: plantId,
        plantCodeSnapshot: plantCodeSnapshot,
        plantNameSnapshot: plantNameSnapshot,
        extractId: extractId,
        extractAbbrSnapshot: extractAbbrSnapshot,
        extractNameSnapshot: extractNameSnapshot,
        testType: testType,
        calibrationId: calibrationId,
        replicates: replicates,
        standardId: standardId,
        standardCodeSnapshot: standardCodeSnapshot,
        controlDOReference: controlDOReference,
        controlMeasurement: controlMeasurement ?? this.controlMeasurement,
        controlMeasuredAt: controlMeasuredAt ?? this.controlMeasuredAt,
        bacteriaId: bacteriaId,
        bacteriaCodeSnapshot: bacteriaCodeSnapshot,
        extractConcentrationMgPerMl: extractConcentrationMgPerMl,
        ic50UgPerMl: ic50UgPerMl ?? this.ic50UgPerMl,
        ec50UgPerMl: ec50UgPerMl ?? this.ec50UgPerMl,
        mgEquivalentPerG: mgEquivalentPerG ?? this.mgEquivalentPerG,
        cmiUgPerMl: cmiUgPerMl ?? this.cmiUgPerMl,
        cmbUgPerMl: cmbUgPerMl ?? this.cmbUgPerMl,
        notes: notes ?? this.notes,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'started_at': startedAt.millisecondsSinceEpoch,
        'completed_at': completedAt?.millisecondsSinceEpoch,
        'status': status,
        'plant_id': plantId,
        'plant_code_snapshot': plantCodeSnapshot,
        'plant_name_snapshot': plantNameSnapshot,
        'extract_id': extractId,
        'extract_abbr_snapshot': extractAbbrSnapshot,
        'extract_name_snapshot': extractNameSnapshot,
        'test_type': testType,
        'calibration_id': calibrationId,
        'replicates': replicates,
        'standard_id': standardId,
        'standard_code_snapshot': standardCodeSnapshot,
        'control_do_reference': controlDOReference,
        'control_measurement': controlMeasurement,
        'control_measured_at': controlMeasuredAt?.millisecondsSinceEpoch,
        'bacteria_id': bacteriaId,
        'bacteria_code_snapshot': bacteriaCodeSnapshot,
        'extract_conc_mg_per_ml': extractConcentrationMgPerMl,
        'ic50_ug_per_ml': ic50UgPerMl,
        'ec50_ug_per_ml': ec50UgPerMl,
        'mg_eq_per_g': mgEquivalentPerG,
        'cmi_ug_per_ml': cmiUgPerMl,
        'cmb_ug_per_ml': cmbUgPerMl,
        'notes': notes,
      };

  factory Session.fromMap(Map<String, Object?> m) => Session(
        id: m['id'] as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(m['started_at'] as int),
        completedAt: m['completed_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['completed_at'] as int),
        status: m['status'] as String,
        plantId: m['plant_id'] as int?,
        plantCodeSnapshot: m['plant_code_snapshot'] as String?,
        plantNameSnapshot: m['plant_name_snapshot'] as String?,
        extractId: m['extract_id'] as int?,
        extractAbbrSnapshot: m['extract_abbr_snapshot'] as String?,
        extractNameSnapshot: m['extract_name_snapshot'] as String?,
        testType: m['test_type'] as String,
        calibrationId: m['calibration_id'] as String?,
        replicates: m['replicates'] as int? ?? 2,
        standardId: m['standard_id'] as int?,
        standardCodeSnapshot: m['standard_code_snapshot'] as String?,
        controlDOReference: (m['control_do_reference'] as num?)?.toDouble(),
        controlMeasurement: (m['control_measurement'] as num?)?.toDouble(),
        controlMeasuredAt: m['control_measured_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['control_measured_at'] as int),
        bacteriaId: m['bacteria_id'] as int?,
        bacteriaCodeSnapshot: m['bacteria_code_snapshot'] as String?,
        extractConcentrationMgPerMl:
            (m['extract_conc_mg_per_ml'] as num?)?.toDouble(),
        ic50UgPerMl: (m['ic50_ug_per_ml'] as num?)?.toDouble(),
        ec50UgPerMl: (m['ec50_ug_per_ml'] as num?)?.toDouble(),
        mgEquivalentPerG: (m['mg_eq_per_g'] as num?)?.toDouble(),
        cmiUgPerMl: (m['cmi_ug_per_ml'] as num?)?.toDouble(),
        cmbUgPerMl: (m['cmb_ug_per_ml'] as num?)?.toDouble(),
        notes: m['notes'] as String?,
      );
}

class WellRole {
  static const sample = 'sample';
  static const controlGrowth = 'control_growth';        // T+ : milieu + bactérie
  static const controlSterility = 'control_sterility';  // T- : milieu seul
  static const controlHE = 'control_he';                // T- HE seule
  static const standard = 'standard';                   // standard antibio
}

class ObservedColor {
  static const mauve = 'mauve'; // résazurine intacte = pas de bactérie
  static const pink = 'pink';   // résorufine = présence de bactérie
}

class Measurement {
  final String id;
  final String sessionId;
  final double concentration;
  final int replicateNumber;
  final double rawDO;
  final DateTime measuredAt;
  final String wellRole;
  final String? observedColor;
  final String? validationStatus;
  final String? validationMessage;
  final bool isExcluded;
  final String? exclusionReason;

  const Measurement({
    required this.id,
    required this.sessionId,
    required this.concentration,
    required this.replicateNumber,
    required this.rawDO,
    required this.measuredAt,
    this.wellRole = WellRole.sample,
    this.observedColor,
    this.validationStatus,
    this.validationMessage,
    this.isExcluded = false,
    this.exclusionReason,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'session_id': sessionId,
        'concentration': concentration,
        'replicate_number': replicateNumber,
        'raw_do': rawDO,
        'measured_at': measuredAt.millisecondsSinceEpoch,
        'well_role': wellRole,
        'observed_color': observedColor,
        'validation_status': validationStatus,
        'validation_message': validationMessage,
        'is_excluded': isExcluded ? 1 : 0,
        'exclusion_reason': exclusionReason,
      };

  factory Measurement.fromMap(Map<String, Object?> m) => Measurement(
        id: m['id'] as String,
        sessionId: m['session_id'] as String,
        concentration: (m['concentration'] as num).toDouble(),
        replicateNumber: m['replicate_number'] as int,
        rawDO: (m['raw_do'] as num).toDouble(),
        measuredAt: DateTime.fromMillisecondsSinceEpoch(m['measured_at'] as int),
        wellRole: m['well_role'] as String? ?? WellRole.sample,
        observedColor: m['observed_color'] as String?,
        validationStatus: m['validation_status'] as String?,
        validationMessage: m['validation_message'] as String?,
        isExcluded: (m['is_excluded'] as int? ?? 0) == 1,
        exclusionReason: m['exclusion_reason'] as String?,
      );
}

class Calibration {
  final String id;
  final String name;
  final String testType;
  final int? standardId;
  final String? standardCodeSnapshot;
  final String standardCompound;
  final String? reagentBatchNumber;
  final DateTime dateCreated;
  final DateTime dateOpenedFlask;
  final int alertAfterDays;
  final int replicates;
  final List<double> concentrations;
  final double? controlDO;
  final double? slope;
  final double? intercept;
  final double? r2;
  final String? notes;
  final DateTime? lastUsed;

  const Calibration({
    required this.id,
    required this.name,
    required this.testType,
    this.standardId,
    this.standardCodeSnapshot,
    required this.standardCompound,
    this.reagentBatchNumber,
    required this.dateCreated,
    required this.dateOpenedFlask,
    this.alertAfterDays = 60,
    this.replicates = 3,
    this.concentrations = const [],
    this.controlDO,
    this.slope,
    this.intercept,
    this.r2,
    this.notes,
    this.lastUsed,
  });

  bool get isExpired {
    final cutoff = dateOpenedFlask.add(Duration(days: alertAfterDays));
    return DateTime.now().isAfter(cutoff);
  }

  bool get isLinearityValid => (r2 ?? 0) >= 0.97;

  Calibration copyWith({
    double? controlDO,
    double? slope,
    double? intercept,
    double? r2,
    String? notes,
    DateTime? lastUsed,
  }) =>
      Calibration(
        id: id,
        name: name,
        testType: testType,
        standardId: standardId,
        standardCodeSnapshot: standardCodeSnapshot,
        standardCompound: standardCompound,
        reagentBatchNumber: reagentBatchNumber,
        dateCreated: dateCreated,
        dateOpenedFlask: dateOpenedFlask,
        alertAfterDays: alertAfterDays,
        replicates: replicates,
        concentrations: concentrations,
        controlDO: controlDO ?? this.controlDO,
        slope: slope ?? this.slope,
        intercept: intercept ?? this.intercept,
        r2: r2 ?? this.r2,
        notes: notes ?? this.notes,
        lastUsed: lastUsed ?? this.lastUsed,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'test_type': testType,
        'standard_id': standardId,
        'standard_code_snapshot': standardCodeSnapshot,
        'standard_compound': standardCompound,
        'reagent_batch_number': reagentBatchNumber,
        'date_created': dateCreated.millisecondsSinceEpoch,
        'date_opened_flask': dateOpenedFlask.millisecondsSinceEpoch,
        'alert_after_days': alertAfterDays,
        'replicates': replicates,
        'concentrations': _encodeConcentrations(concentrations),
        'control_do': controlDO,
        'slope': slope,
        'intercept': intercept,
        'r2': r2,
        'notes': notes,
        'last_used': lastUsed?.millisecondsSinceEpoch,
      };

  factory Calibration.fromMap(Map<String, Object?> m) => Calibration(
        id: m['id'] as String,
        name: m['name'] as String,
        testType: m['test_type'] as String,
        standardId: m['standard_id'] as int?,
        standardCodeSnapshot: m['standard_code_snapshot'] as String?,
        standardCompound: m['standard_compound'] as String,
        reagentBatchNumber: m['reagent_batch_number'] as String?,
        dateCreated: DateTime.fromMillisecondsSinceEpoch(m['date_created'] as int),
        dateOpenedFlask:
            DateTime.fromMillisecondsSinceEpoch(m['date_opened_flask'] as int),
        alertAfterDays: m['alert_after_days'] as int? ?? 60,
        replicates: m['replicates'] as int? ?? 3,
        concentrations: _decodeConcentrations(m['concentrations'] as String?),
        controlDO: (m['control_do'] as num?)?.toDouble(),
        slope: (m['slope'] as num?)?.toDouble(),
        intercept: (m['intercept'] as num?)?.toDouble(),
        r2: (m['r2'] as num?)?.toDouble(),
        notes: m['notes'] as String?,
        lastUsed: m['last_used'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['last_used'] as int),
      );

  static String? _encodeConcentrations(List<double> concs) =>
      concs.isEmpty ? null : concs.map((e) => e.toString()).join(',');

  static List<double> _decodeConcentrations(String? raw) =>
      raw == null || raw.isEmpty
          ? const []
          : raw.split(',').where((p) => p.isNotEmpty).map(double.parse).toList();
}

class CalibrationPoint {
  final int? id;
  final String calibrationId;
  final double concentration;

  /// Réplicats. `null` à un index = case non encore saisie.
  final List<double?> doReplicates;
  final bool retainedForFit;

  const CalibrationPoint({
    this.id,
    required this.calibrationId,
    required this.concentration,
    required this.doReplicates,
    this.retainedForFit = true,
  });

  Iterable<double> get validReplicates =>
      doReplicates.whereType<double>().where((v) => !v.isNaN);

  double? get meanDO {
    final valid = validReplicates.toList();
    if (valid.isEmpty) return null;
    return valid.reduce((a, b) => a + b) / valid.length;
  }
}
