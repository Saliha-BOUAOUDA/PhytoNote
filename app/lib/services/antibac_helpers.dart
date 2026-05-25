import '../config/catalog.dart';
import '../data/models.dart';

/// Concentrations CLSI standard pour la sérige diluée /2 du standard antibio,
/// en µg/mL. Référence : CLSI M07-A11 (microdilution MIC).
List<double> standardAntibioticConcentrations() {
  return const [
    64, 32, 16, 8, 4, 2, 1, 0.5, 0.25, 0.125, 0.0625,
  ];
}

/// MIC attendues littérature pour validation interne du standard.
/// Si le standard ne tombe pas dans cette plage avec la souche utilisée,
/// la manip est invalide.
///
/// Match sur les **abréviations** du jargon scientifique (CIP, GENT pour les
/// antibios ; *S. aureus*, *E. coli*, *S. pyogenes* pour les bactéries).
/// Si l'utilisateur a customisé son code en dehors de ces standards, on
/// retourne `null` (= « plage attendue inconnue »), comportement gracieux.
({double low, double high})? expectedStandardMICRange({
  required String standardAbbreviation,
  required String bacteriaAbbreviation,
}) {
  if (standardAbbreviation == 'CIP') {
    switch (bacteriaAbbreviation) {
      case 'E. coli':
        return (low: 0.008, high: 0.03);
      case 'S. aureus':
        return (low: 0.25, high: 1.0);
      case 'S. pyogenes':
        return (low: 0.5, high: 2.0);
    }
  }
  if (standardAbbreviation == 'GENT') {
    switch (bacteriaAbbreviation) {
      case 'E. coli':
        return (low: 0.5, high: 2.0);
      case 'S. aureus':
        return (low: 0.5, high: 2.0);
      case 'S. pyogenes':
        return (low: 8.0, high: 32.0);
    }
  }
  return null;
}

/// Détermination automatique de la CMI :
/// la plus petite [C] où *tous* les réplicats observés sont mauves
/// (= résazurine intacte = inhibition bactérienne).
double? computeCMI({
  required List<Measurement> measurements,
  required List<double> sortedConcentrationsDescending,
  required String wellRole,
}) {
  double? cmi;
  for (final c in sortedConcentrationsDescending) {
    final reps = measurements.where(
      (m) => m.wellRole == wellRole && _approxEqual(m.concentration, c),
    );
    if (reps.isEmpty) return cmi;
    final allMauve = reps.every((m) => m.observedColor == ObservedColor.mauve);
    if (allMauve) {
      cmi = c;
    } else {
      return cmi;
    }
  }
  return cmi;
}

bool _approxEqual(double a, double b) => (a - b).abs() < 1e-9;

/// Validation des contrôles obligatoires d'une manip antibactérienne.
List<String> validateAntibacControls(List<Measurement> controls) {
  final issues = <String>[];

  final tPlus = controls.where((m) => m.wellRole == WellRole.controlGrowth).toList();
  if (tPlus.isEmpty) {
    issues.add('Contrôle T+ croissance manquant');
  } else if (tPlus.any((m) => m.observedColor == ObservedColor.mauve)) {
    issues.add('T+ croissance mauve : la bactérie n\'a pas poussé → manip invalide');
  }

  final tMinus = controls.where((m) => m.wellRole == WellRole.controlSterility).toList();
  if (tMinus.isEmpty) {
    issues.add('Contrôle T− stérilité manquant');
  } else if (tMinus.any((m) => m.observedColor == ObservedColor.pink)) {
    issues.add('T− stérilité rose : milieu contaminé → manip invalide');
  }

  final tHE = controls.where((m) => m.wellRole == WellRole.controlHE).toList();
  if (tHE.isEmpty) {
    issues.add('Contrôle T− HE manquant');
  } else if (tHE.any((m) => m.observedColor == ObservedColor.pink)) {
    issues.add('T− HE rose : huile contaminée → manip invalide');
  }

  return issues;
}

String describeConcentration(double c, TestDefinition test) =>
    formatConcentration(c, test.concentrationUnit);
