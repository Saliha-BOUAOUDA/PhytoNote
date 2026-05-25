import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/catalog.dart';
import '../data/catalog_models.dart';
import '../data/models.dart';
import '../services/antibac_helpers.dart';
import '../services/regression.dart';
import '../services/results.dart';

/// Génère un fichier .xlsx + déclenche le share intent natif.
Future<File> exportSessionToExcel({
  required Session session,
  required TestDefinition test,
  Plant? plant,
  Calibration? calibration,
  Standard? standard,
  required List<Measurement> measurements,
  required SessionResults results,
}) async {
  final excel = xls.Excel.createExcel();
  excel.delete('Sheet1');

  final plantLabel = session.plantCodeSnapshot ?? '?';
  final extractLabel = session.extractAbbrSnapshot ?? '?';

  final cover = excel['Cover'];
  _addTitle(cover, 'Manip ${test.code} · $plantLabel · $extractLabel');
  _addKVRow(cover, 'Plante', '${plant?.name ?? plantLabel} ($plantLabel)');
  if (plant?.scientificName != null) {
    _addKVRow(cover, 'Nom scientifique', plant!.scientificName!);
  }
  _addKVRow(cover, 'Type d\'extrait',
      '${session.extractNameSnapshot ?? extractLabel} ($extractLabel)');
  _addKVRow(cover, 'Test', '${test.name} (${test.code}) — ${test.shortDescription}');
  _addKVRow(cover, 'Référence méthode', test.reference);
  _addKVRow(cover, 'Longueur d\'onde', '${test.wavelengthNm} nm');
  if (standard != null) {
    _addKVRow(cover, 'Standard de référence',
        '${standard.name} (${standard.abbreviation})');
    _addKVRow(cover, 'Équivalents exprimés en', standard.equivalentLabel);
  }
  if (session.bacteriaCodeSnapshot != null) {
    _addKVRow(cover, 'Souche bactérienne', session.bacteriaCodeSnapshot!);
  }
  _addKVRow(cover, 'Réplicats', session.replicates.toString());
  _addKVRow(cover, 'Démarrée le', _fmtDateTime(session.startedAt));
  if (session.completedAt != null) {
    _addKVRow(cover, 'Terminée le', _fmtDateTime(session.completedAt!));
  }
  _addKVRow(cover, 'Statut', _statusLabel(session.status));
  if (session.controlDOReference != null) {
    _addKVRow(cover, 'DO contrôle attendue',
        session.controlDOReference!.toStringAsFixed(3));
  }
  if (session.controlMeasurement != null) {
    _addKVRow(cover, 'DO contrôle mesurée',
        session.controlMeasurement!.toStringAsFixed(3));
  }
  if (session.notes != null && session.notes!.isNotEmpty) {
    _addKVRow(cover, 'Notes', session.notes!);
  }
  _addKVRow(cover, 'Exporté le', _fmtDateTime(DateTime.now()));
  _addKVRow(cover, 'App', 'PhytoNote');

  if (calibration != null) {
    final cal = excel['Calibration'];
    _addTitle(cal, 'Calibration liée');
    _addKVRow(cal, 'Nom', calibration.name);
    _addKVRow(cal, 'Lot', calibration.reagentBatchNumber ?? '—');
    _addKVRow(cal, 'Date d\'ouverture', _fmtDate(calibration.dateOpenedFlask));
    _addKVRow(cal, 'Pente', calibration.slope?.toStringAsFixed(4) ?? '—');
    _addKVRow(cal, 'Ordonnée', calibration.intercept?.toStringAsFixed(4) ?? '—');
    _addKVRow(cal, 'R²', calibration.r2?.toStringAsFixed(4) ?? '—');
    if (calibration.controlDO != null) {
      _addKVRow(cal, 'DO contrôle', calibration.controlDO!.toStringAsFixed(3));
    }
  }

  final raw = excel['Mesures brutes'];
  raw.appendRow([
    xls.TextCellValue('Concentration'),
    xls.TextCellValue('Unité'),
    xls.TextCellValue('Réplicat'),
    xls.TextCellValue('DO'),
    xls.TextCellValue('Heure'),
    xls.TextCellValue('Statut validation'),
    xls.TextCellValue('Exclu'),
    xls.TextCellValue('Raison exclusion'),
  ]);
  final sortedMeasurements = [...measurements]..sort((a, b) {
    final c = b.concentration.compareTo(a.concentration);
    return c != 0 ? c : a.replicateNumber.compareTo(b.replicateNumber);
  });
  for (final m in sortedMeasurements) {
    raw.appendRow([
      xls.DoubleCellValue(m.concentration),
      xls.TextCellValue(test.concentrationUnit),
      xls.IntCellValue(m.replicateNumber),
      xls.DoubleCellValue(m.rawDO),
      xls.TextCellValue(_fmtTime(m.measuredAt)),
      xls.TextCellValue(m.validationStatus ?? ''),
      xls.TextCellValue(m.isExcluded ? 'oui' : 'non'),
      xls.TextCellValue(m.exclusionReason ?? ''),
    ]);
  }

  final calc = excel['Calculs'];
  calc.appendRow([
    xls.TextCellValue('Concentration'),
    xls.TextCellValue('Unité'),
    xls.TextCellValue('DO moyenne'),
    xls.TextCellValue('Réplicats'),
    xls.TextCellValue('Y régression'),
  ]);
  final yLabel = test.regressionYType == RegressionYType.inhibitionPercent
      ? '% inhibition'
      : 'DO';
  final controlDO = session.controlMeasurement ?? session.controlDOReference ?? 0;
  final byConc = <double, List<double>>{};
  for (final m in measurements.where((m) => !m.isExcluded)) {
    byConc.putIfAbsent(m.concentration, () => []).add(m.rawDO);
  }
  final sortedConcs = byConc.keys.toList()..sort((a, b) => b.compareTo(a));
  for (final c in sortedConcs) {
    final reps = byConc[c]!;
    final mean = reps.reduce((a, b) => a + b) / reps.length;
    final y = test.regressionYType == RegressionYType.inhibitionPercent && controlDO > 0
        ? (1 - mean / controlDO) * 100
        : mean;
    calc.appendRow([
      xls.DoubleCellValue(c),
      xls.TextCellValue(test.concentrationUnit),
      xls.DoubleCellValue(double.parse(mean.toStringAsFixed(4))),
      xls.IntCellValue(reps.length),
      xls.DoubleCellValue(double.parse(y.toStringAsFixed(4))),
    ]);
  }
  calc.appendRow([]);
  calc.appendRow([xls.TextCellValue('Légende Y'), xls.TextCellValue(yLabel)]);

  final reg = excel['Régression échantillon'];
  if (results.sampleRegression != null) {
    final r = results.sampleRegression!;
    _addKVRow(reg, 'Pente', r.slope.toStringAsFixed(6));
    _addKVRow(reg, 'Ordonnée', r.intercept.toStringAsFixed(6));
    _addKVRow(reg, 'R²', r.r2.toStringAsFixed(6));
    _addKVRow(reg, 'n points', r.n.toString());
    _addKVRow(reg, 'Équation', r.formatEquation());
    _addKVRow(reg, 'Linéarité valide (R²≥0.97)',
        r.isLinearityValid ? 'oui' : 'non');
    if (results.ic50 != null) {
      _addKVRow(reg, 'IC50',
          '${results.ic50!.toStringAsFixed(3)} ${test.concentrationUnit}');
    }
    if (results.equivalentMgPerMl != null) {
      final eqLabel = standard?.equivalentLabel ?? 'STD';
      _addKVRow(reg, 'Équivalent moyen',
          '${results.equivalentMgPerMl!.toStringAsFixed(4)} mg $eqLabel/mL');
    }
  } else {
    _addKVRow(reg, 'Statut', 'Pas assez de points pour la régression');
  }
  for (final w in results.warnings) {
    _addKVRow(reg, 'Avertissement', w);
  }

  return _saveAndShare(
    excel,
    filename: _filename('Manip', '$plantLabel-${test.code}-$extractLabel'),
    subject: 'Manip ${test.code} · $plantLabel',
    text: 'Résultats de la manip ${test.code} sur ${plant?.name ?? plantLabel}',
  );
}

Future<File> exportAntibacSessionToExcel({
  required Session session,
  required TestDefinition test,
  Plant? plant,
  Bacteria? bacteria,
  Standard? standard,
  required List<Measurement> measurements,
  required List<double> sampleConcentrations,
  required List<double> standardConcentrations,
  required double? cmiSample,
  required double? cmiStandard,
  required List<String> controlIssues,
}) async {
  final excel = xls.Excel.createExcel();
  excel.delete('Sheet1');

  final plantLabel = session.plantCodeSnapshot ?? '?';
  final extractLabel = session.extractAbbrSnapshot ?? '?';

  final cover = excel['Cover'];
  _addTitle(cover, 'Plaque antibactérienne · $plantLabel');
  _addKVRow(cover, 'Plante', '${plant?.name ?? plantLabel} ($plantLabel)');
  _addKVRow(cover, 'Type d\'extrait',
      '${session.extractNameSnapshot ?? extractLabel} ($extractLabel)');
  _addKVRow(cover, 'Test', '${test.name} — ${test.shortDescription}');
  _addKVRow(cover, 'Référence', test.reference);
  if (bacteria != null) {
    _addKVRow(cover, 'Souche', '${bacteria.name} (Gram ${bacteria.gram})');
    if (bacteria.atccSuggested != null) {
      _addKVRow(cover, 'ATCC', bacteria.atccSuggested!);
    }
  }
  if (standard != null) {
    _addKVRow(cover, 'Standard antibio',
        '${standard.name} (${standard.abbreviation})');
  }
  _addKVRow(cover, 'Démarrée le', _fmtDateTime(session.startedAt));
  if (session.completedAt != null) {
    _addKVRow(cover, 'Terminée le', _fmtDateTime(session.completedAt!));
  }
  _addKVRow(cover, 'Réplicats', session.replicates.toString());
  _addKVRow(cover, 'Exporté le', _fmtDateTime(DateTime.now()));

  final controls = excel['Contrôles'];
  controls.appendRow([
    xls.TextCellValue('Type'),
    xls.TextCellValue('DO 600 nm'),
    xls.TextCellValue('Couleur résazurine'),
    xls.TextCellValue('Heure'),
  ]);
  for (final m in measurements.where((m) =>
      m.wellRole == WellRole.controlGrowth ||
      m.wellRole == WellRole.controlSterility ||
      m.wellRole == WellRole.controlHE)) {
    controls.appendRow([
      xls.TextCellValue(_wellRoleLabel(m.wellRole)),
      xls.DoubleCellValue(m.rawDO),
      xls.TextCellValue(m.observedColor ?? '—'),
      xls.TextCellValue(_fmtTime(m.measuredAt)),
    ]);
  }
  if (controlIssues.isNotEmpty) {
    controls.appendRow([]);
    controls.appendRow([xls.TextCellValue('Problèmes détectés')]);
    for (final i in controlIssues) {
      controls.appendRow([xls.TextCellValue(i)]);
    }
  }

  final sample = excel['Échantillon'];
  _writePlateSection(sample, 'Sérige diluée extrait', measurements,
      WellRole.sample, sampleConcentrations, test.concentrationUnit);

  final stdSheet = excel['Standard antibio'];
  _writePlateSection(stdSheet, 'Sérige diluée standard', measurements,
      WellRole.standard, standardConcentrations, 'µg/mL');

  final results = excel['Résultats'];
  _addKVRow(
      results,
      'CMI échantillon',
      cmiSample != null
          ? '${cmiSample.toStringAsFixed(3)} ${test.concentrationUnit}'
          : '—');
  _addKVRow(
      results,
      'CMI standard antibio',
      cmiStandard != null
          ? '${cmiStandard.toStringAsFixed(3)} µg/mL'
          : '—');
  if (standard != null && bacteria != null) {
    final range = expectedStandardMICRange(
      standardAbbreviation: standard.abbreviation,
      bacteriaAbbreviation: bacteria.abbreviation,
    );
    if (range != null) {
      _addKVRow(results, 'Plage CLSI attendue',
          '${range.low}–${range.high} µg/mL');
      if (cmiStandard != null) {
        final inRange = cmiStandard >= range.low && cmiStandard <= range.high;
        _addKVRow(results, 'Validation standard',
            inRange ? '✓ Conforme' : '⚠ Hors plage');
      }
    }
  }
  if (session.cmbUgPerMl != null) {
    _addKVRow(results, 'CMB échantillon',
        '${session.cmbUgPerMl!.toStringAsFixed(3)} ${test.concentrationUnit}');
  }
  _addKVRow(
      results,
      'Contrôles validés',
      controlIssues.isEmpty
          ? '✓ Tous OK'
          : '⚠ ${controlIssues.length} problème(s)');

  return _saveAndShare(
    excel,
    filename: _filename('Plaque',
        '$plantLabel-${test.code}-${session.bacteriaCodeSnapshot ?? "?"}'),
    subject: 'Plaque ${test.code} · $plantLabel',
    text: 'Plaque microdilution ${test.code} sur ${plant?.name ?? plantLabel}',
  );
}

Future<File> exportCalibrationToExcel({
  required Calibration calibration,
  required TestDefinition test,
  Standard? standard,
  required List<CalibrationPoint> points,
  required RegressionResult? regression,
}) async {
  final excel = xls.Excel.createExcel();
  excel.delete('Sheet1');

  final cover = excel['Cover'];
  _addTitle(cover,
      'Calibration ${test.code} · ${standard?.name ?? calibration.standardCompound}');
  _addKVRow(cover, 'Test', '${test.name} (${test.code})');
  _addKVRow(cover, 'Référence', test.reference);
  _addKVRow(cover, 'Longueur d\'onde', '${test.wavelengthNm} nm');
  if (standard != null) {
    _addKVRow(cover, 'Standard',
        '${standard.name} (${standard.abbreviation})');
    _addKVRow(cover, 'Équivalents', standard.equivalentLabel);
    if (standard.molarMassGperMol != null) {
      _addKVRow(cover, 'Masse molaire', '${standard.molarMassGperMol} g/mol');
    }
  }
  _addKVRow(cover, 'Lot de réactif', calibration.reagentBatchNumber ?? '—');
  _addKVRow(cover, 'Date d\'ouverture', _fmtDate(calibration.dateOpenedFlask));
  _addKVRow(cover, 'Date de création', _fmtDate(calibration.dateCreated));
  _addKVRow(cover, 'Réplicats', calibration.replicates.toString());
  _addKVRow(cover, 'Nb dilutions', calibration.concentrations.length.toString());
  if (calibration.controlDO != null) {
    _addKVRow(cover, 'DO contrôle', calibration.controlDO!.toStringAsFixed(3));
  }
  _addKVRow(cover, 'Exporté le', _fmtDateTime(DateTime.now()));
  _addKVRow(cover, 'App', 'PhytoNote');

  final pts = excel['Points'];
  final headers = <xls.CellValue>[
    xls.TextCellValue('Concentration'),
    xls.TextCellValue('Unité'),
  ];
  for (var i = 0; i < calibration.replicates; i++) {
    headers.add(xls.TextCellValue('R${i + 1}'));
  }
  headers.addAll([
    xls.TextCellValue('DO moyenne'),
    xls.TextCellValue('Y régression'),
    xls.TextCellValue('Retenu'),
  ]);
  pts.appendRow(headers);

  final controlDO = calibration.controlDO ?? 0;
  final isInhib = test.regressionYType == RegressionYType.inhibitionPercent;
  for (final p in points) {
    final mean = p.meanDO;
    final y = mean == null
        ? null
        : (isInhib && controlDO > 0 ? (1 - mean / controlDO) * 100 : mean);
    final row = <xls.CellValue>[
      xls.DoubleCellValue(p.concentration),
      xls.TextCellValue(test.concentrationUnit),
    ];
    for (var i = 0; i < calibration.replicates; i++) {
      final v = i < p.doReplicates.length ? p.doReplicates[i] : null;
      row.add(v == null ? xls.TextCellValue('') : xls.DoubleCellValue(v));
    }
    row.addAll([
      mean == null
          ? xls.TextCellValue('—')
          : xls.DoubleCellValue(double.parse(mean.toStringAsFixed(4))),
      y == null
          ? xls.TextCellValue('—')
          : xls.DoubleCellValue(double.parse(y.toStringAsFixed(4))),
      xls.TextCellValue(p.retainedForFit ? 'oui' : 'non'),
    ]);
    pts.appendRow(row);
  }

  final regSheet = excel['Régression'];
  if (regression != null) {
    _addKVRow(regSheet, 'Pente', regression.slope.toStringAsFixed(6));
    _addKVRow(regSheet, 'Ordonnée', regression.intercept.toStringAsFixed(6));
    _addKVRow(regSheet, 'R²', regression.r2.toStringAsFixed(6));
    _addKVRow(regSheet, 'n points retenus', regression.n.toString());
    _addKVRow(regSheet, 'Équation', regression.formatEquation());
    _addKVRow(regSheet, 'Linéarité valide (R²≥0.97)',
        regression.isLinearityValid ? 'oui' : 'non');
    final retainedConcs = points
        .where((p) => p.retainedForFit)
        .map((p) => p.concentration)
        .toList()
      ..sort();
    if (retainedConcs.isNotEmpty) {
      _addKVRow(regSheet, 'Plage retenue',
          '${retainedConcs.first} – ${retainedConcs.last} ${test.concentrationUnit}');
    }
  } else {
    _addKVRow(regSheet, 'Statut', 'Pas assez de points pour la régression');
  }

  return _saveAndShare(
    excel,
    filename: _filename('Calibration', '${test.code}-${calibration.standardCompound}'),
    subject: 'Calibration ${test.code} · ${standard?.abbreviation ?? calibration.standardCompound}',
    text: 'Calibration ${test.code} avec ${standard?.name ?? calibration.standardCompound}',
  );
}

void _addTitle(xls.Sheet sheet, String title) {
  sheet.appendRow([xls.TextCellValue(title)]);
  sheet.appendRow([]);
}

void _addKVRow(xls.Sheet sheet, String key, String value) {
  sheet.appendRow([xls.TextCellValue(key), xls.TextCellValue(value)]);
}

void _writePlateSection(
  xls.Sheet sheet,
  String title,
  List<Measurement> measurements,
  String wellRole,
  List<double> concentrations,
  String unit,
) {
  _addTitle(sheet, title);
  sheet.appendRow([
    xls.TextCellValue('Concentration'),
    xls.TextCellValue('Unité'),
    xls.TextCellValue('Réplicat'),
    xls.TextCellValue('DO 600 nm'),
    xls.TextCellValue('Couleur résazurine'),
    xls.TextCellValue('Heure'),
  ]);
  final filtered = measurements.where((m) => m.wellRole == wellRole).toList()
    ..sort((a, b) {
      final c = b.concentration.compareTo(a.concentration);
      return c != 0 ? c : a.replicateNumber.compareTo(b.replicateNumber);
    });
  for (final m in filtered) {
    sheet.appendRow([
      xls.DoubleCellValue(m.concentration),
      xls.TextCellValue(unit),
      xls.IntCellValue(m.replicateNumber),
      xls.DoubleCellValue(m.rawDO),
      xls.TextCellValue(m.observedColor ?? '—'),
      xls.TextCellValue(_fmtTime(m.measuredAt)),
    ]);
  }
}

String _wellRoleLabel(String role) {
  switch (role) {
    case WellRole.controlGrowth: return 'T+ croissance';
    case WellRole.controlSterility: return 'T− stérilité';
    case WellRole.controlHE: return 'T− HE seule';
    case WellRole.standard: return 'Standard';
    default: return 'Échantillon';
  }
}

String _statusLabel(String status) {
  switch (status) {
    case SessionStatus.active: return 'En cours';
    case SessionStatus.completed: return 'Terminée';
    case SessionStatus.aborted: return 'Abandonnée';
    default: return status;
  }
}

String _fmtDateTime(DateTime d) => DateFormat('yyyy-MM-dd HH:mm').format(d);
String _fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String _fmtTime(DateTime d) => DateFormat('HH:mm:ss').format(d);

String _filename(String prefix, String suffix) {
  final ts = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
  final safe = suffix.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
  return 'PhytoNote_${prefix}_${safe}_$ts.xlsx';
}

Future<Directory> _exportsDir() async {
  final root = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(root.path, 'PhytoNote_exports'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

Future<File> _saveAndShare(
  xls.Excel excel, {
  required String filename,
  required String subject,
  required String text,
}) async {
  final bytes = excel.save();
  if (bytes == null) {
    throw Exception('Échec de l\'encodage Excel');
  }
  final dir = await _exportsDir();
  final filePath = p.join(dir.path, filename);
  final file = File(filePath);
  await file.writeAsBytes(bytes);

  if (Platform.isAndroid || Platform.isIOS) {
    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      subject: subject,
      text: text,
    );
  }

  return file;
}

Future<void> openExportsFolder() async {
  final dir = await _exportsDir();
  String? cmd;
  if (Platform.isLinux) cmd = 'xdg-open';
  if (Platform.isMacOS) cmd = 'open';
  if (Platform.isWindows) cmd = 'explorer';
  if (cmd == null) return;
  try {
    await Process.start(cmd, [dir.path], mode: ProcessStartMode.detached);
  } catch (_) {
    // Pas de gestionnaire de fichiers disponible — silencieux.
  }
}
