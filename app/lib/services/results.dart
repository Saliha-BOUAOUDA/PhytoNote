import '../config/catalog.dart';
import '../data/models.dart';
import 'regression.dart';

class SessionResults {
  /// Régression linéaire sur les points retenus de l'échantillon.
  final RegressionResult? sampleRegression;

  /// IC50 dans l'unité de concentration du test (µg/mL ou mg/mL).
  /// Calculé seulement pour les tests inhibition (DPPH/ABTS/ANTIINF) si la
  /// régression a une pente non-nulle ; null sinon.
  final double? ic50;

  /// Concentration moyenne en équivalent du standard (mg STD/mL en tube).
  /// Calculé seulement pour les tests absorbance (FRAP/CAT/TPC/TFC) si une
  /// calibration valide est attachée à la session.
  final double? equivalentMgPerMl;

  /// Points (x = concentration, y = %inh ou DO) à afficher dans le graph.
  final List<({double x, double y})> chartPoints;

  /// Légende de l'axe Y (« % inhibition » ou « DO »).
  final String yLabel;

  /// Légende de l'axe X (l'unité de concentration du test).
  final String xUnit;

  /// Avertissements (manque de contrôle, manque de calibration…).
  final List<String> warnings;

  const SessionResults({
    this.sampleRegression,
    this.ic50,
    this.equivalentMgPerMl,
    this.chartPoints = const [],
    required this.yLabel,
    required this.xUnit,
    this.warnings = const [],
  });
}

/// Calcule en live les résultats d'une session à partir des mesures saisies.
SessionResults computeSessionResults({
  required Session session,
  required TestDefinition test,
  Calibration? calibration,
  required List<Measurement> measurements,
}) {
  final unit = test.concentrationUnit;
  final yLabel = test.regressionYType == RegressionYType.inhibitionPercent
      ? '% inhibition'
      : 'DO';
  final warnings = <String>[];

  // Filtre : seules les mesures non-exclues, au rôle 'sample' (exclut les
  // contrôles + standards d'un éventuel écran plaque).
  final samples = measurements.where((m) =>
      !m.isExcluded && (m.wellRole == WellRole.sample)).toList();

  if (samples.isEmpty) {
    return SessionResults(yLabel: yLabel, xUnit: unit, warnings: warnings);
  }

  // Groupe par concentration → moyenne DO par concentration.
  final Map<double, List<double>> byConc = {};
  for (final m in samples) {
    byConc.putIfAbsent(m.concentration, () => []).add(m.rawDO);
  }
  final pointsByConc = byConc.entries
      .map((e) => (concentration: e.key, meanDO: e.value.reduce((a, b) => a + b) / e.value.length))
      .toList()
    ..sort((a, b) => a.concentration.compareTo(b.concentration));

  // === Tests à inhibition (DPPH/ABTS/ANTIINF) ===
  if (test.regressionYType == RegressionYType.inhibitionPercent) {
    final controlDO = session.controlMeasurement ?? session.controlDOReference;
    if (controlDO == null || controlDO == 0) {
      warnings.add('DO contrôle manquante : impossible de calculer % inhibition');
      return SessionResults(yLabel: yLabel, xUnit: unit, warnings: warnings);
    }
    final inhPoints = pointsByConc
        .map((p) => (x: p.concentration, y: (1 - p.meanDO / controlDO) * 100))
        .toList();
    final reg = linearRegression(inhPoints);
    double? ic50;
    if (reg != null && reg.slope != 0) {
      ic50 = (50 - reg.intercept) / reg.slope;
      if (ic50 < 0 || ic50.isNaN || ic50.isInfinite) ic50 = null;
    }
    return SessionResults(
      sampleRegression: reg,
      ic50: ic50,
      chartPoints: inhPoints,
      yLabel: yLabel,
      xUnit: unit,
      warnings: warnings,
    );
  }

  // === Tests à absorbance (FRAP/CAT/TPC/TFC) ===
  final doPoints = pointsByConc.map((p) => (x: p.concentration, y: p.meanDO)).toList();
  double? equivalentMgPerMl;
  if (calibration != null &&
      calibration.slope != null &&
      calibration.slope != 0 &&
      calibration.intercept != null) {
    // Pour chaque point sample, calcule l'équivalent en concentration
    // de standard (mg STD/mL) qui aurait donné la même DO.
    // Puis fait la moyenne pondérée par concentration sample.
    final equivs = pointsByConc.map((p) {
      final eqStd = (p.meanDO - calibration.intercept!) / calibration.slope!;
      return eqStd; // dans l'unité de la calibration (mg/mL ou µg/mL)
    }).where((v) => v > 0).toList();
    if (equivs.isNotEmpty) {
      equivalentMgPerMl = equivs.reduce((a, b) => a + b) / equivs.length;
    }
  } else {
    warnings.add('Aucune calibration liée — équivalents en standard non calculés');
  }

  final reg = linearRegression(doPoints);
  return SessionResults(
    sampleRegression: reg,
    equivalentMgPerMl: equivalentMgPerMl,
    chartPoints: doPoints,
    yLabel: yLabel,
    xUnit: unit,
    warnings: warnings,
  );
}
