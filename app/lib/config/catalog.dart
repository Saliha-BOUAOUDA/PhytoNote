/// Tests scientifiques supportés par PhytoNote + utilitaires de plan d'acquisition.
///
/// **Note v7 :** ce fichier ne contient plus que ce qui est *protocole*
/// scientifique (tests, plages de concentrations, formules). Toutes les
/// entités du catalogue (plantes, extraits, standards, bactéries, enzymes)
/// sont désormais purement dynamiques — voir `lib/data/catalog_models.dart`.
library;

enum RegressionYType {
  /// y = (1 - DO/DOcontrol) × 100   — nécessite controlDO sur la calibration
  inhibitionPercent,

  /// y = DO directement (FRAP, CAT, TPC, TFC)
  absorbance,
}

class TestDefinition {
  final String code;
  final String name;
  final String shortDescription;
  final int wavelengthNm;
  final double? defaultControlDO;
  final int defaultReplicates;
  final String concentrationUnit;
  final bool isSinglePointAssay;
  final List<String> compatibleStandardAbbreviations;
  final bool requiresPlateView;
  final bool requiresBacteriaStrain;
  final bool supportsCalibration;
  final RegressionYType regressionYType;
  final String reference;

  const TestDefinition({
    required this.code,
    required this.name,
    required this.shortDescription,
    required this.wavelengthNm,
    this.defaultControlDO,
    required this.defaultReplicates,
    required this.concentrationUnit,
    this.isSinglePointAssay = false,
    required this.compatibleStandardAbbreviations,
    this.requiresPlateView = false,
    this.requiresBacteriaStrain = false,
    this.supportsCalibration = true,
    this.regressionYType = RegressionYType.absorbance,
    required this.reference,
  });

  String get defaultStandardAbbreviation => compatibleStandardAbbreviations.first;
  bool get needsControlDO => regressionYType == RegressionYType.inhibitionPercent;
}

const testsCatalog = <TestDefinition>[
  TestDefinition(
    code: 'DPPH',
    name: 'DPPH',
    shortDescription: 'Activité anti-radicalaire',
    wavelengthNm: 517,
    defaultControlDO: 1.300,
    defaultReplicates: 2,
    concentrationUnit: 'µg/mL',
    compatibleStandardAbbreviations: ['AA', 'BHT', 'TRX'],
    regressionYType: RegressionYType.inhibitionPercent,
    reference: 'Brand-Williams 1995',
  ),
  TestDefinition(
    code: 'ABTS',
    name: 'ABTS',
    shortDescription: 'Activité anti-radicalaire ABTS•+',
    wavelengthNm: 734,
    defaultControlDO: 0.724,
    defaultReplicates: 2,
    concentrationUnit: 'µg/mL',
    compatibleStandardAbbreviations: ['TRX', 'AA'],
    regressionYType: RegressionYType.inhibitionPercent,
    reference: 'Re et al. 1999',
  ),
  TestDefinition(
    code: 'FRAP',
    name: 'FRAP',
    shortDescription: 'Pouvoir réducteur du Fe³⁺',
    wavelengthNm: 700,
    defaultControlDO: null,
    defaultReplicates: 2,
    concentrationUnit: 'mg/mL',
    compatibleStandardAbbreviations: ['AA'],
    regressionYType: RegressionYType.absorbance,
    reference: 'Benzie & Strain 1996',
  ),
  TestDefinition(
    code: 'CAT',
    name: 'CAT (TAC)',
    shortDescription: 'Capacité antioxydante totale',
    wavelengthNm: 695,
    defaultControlDO: null,
    defaultReplicates: 3,
    concentrationUnit: 'mg/mL',
    isSinglePointAssay: true,
    compatibleStandardAbbreviations: ['BHT', 'AA', 'TRX'],
    regressionYType: RegressionYType.absorbance,
    reference: 'Prieto 1999',
  ),
  TestDefinition(
    code: 'TPC',
    name: 'TPC',
    shortDescription: 'Polyphénols totaux',
    wavelengthNm: 765,
    defaultControlDO: null,
    defaultReplicates: 3,
    concentrationUnit: 'µg/mL',
    isSinglePointAssay: true,
    compatibleStandardAbbreviations: ['GA'],
    regressionYType: RegressionYType.absorbance,
    reference: 'Singleton & Rossi 1965',
  ),
  TestDefinition(
    code: 'TFC',
    name: 'TFC',
    shortDescription: 'Flavonoïdes totaux',
    wavelengthNm: 415,
    defaultControlDO: null,
    defaultReplicates: 2,
    concentrationUnit: 'µg/mL',
    isSinglePointAssay: true,
    compatibleStandardAbbreviations: ['QUE', 'CAT_S'],
    regressionYType: RegressionYType.absorbance,
    reference: 'Zhishen et al. 1999',
  ),
  TestDefinition(
    code: 'ANTIBAC',
    name: 'Antibactérien',
    shortDescription: 'Microdilution MIC/MBC',
    wavelengthNm: 600,
    defaultControlDO: null,
    defaultReplicates: 2,
    concentrationUnit: 'µl/mL',
    compatibleStandardAbbreviations: ['CIP', 'GENT'],
    requiresPlateView: true,
    requiresBacteriaStrain: true,
    supportsCalibration: false,
    reference: 'CLSI M07-A11',
  ),
  TestDefinition(
    code: 'ANTIINF',
    name: 'Anti-inflammatoire',
    shortDescription: 'BSA denaturation',
    wavelengthNm: 660,
    defaultControlDO: 0.500,
    defaultReplicates: 3,
    concentrationUnit: 'µg/mL',
    compatibleStandardAbbreviations: ['DICLO', 'ASA', 'INDO'],
    regressionYType: RegressionYType.inhibitionPercent,
    reference: 'Sarveswaran 2017 (review)',
  ),
];

/// Combien de dilutions /2 par défaut pour les tests à série (DPPH/ABTS/FRAP).
const int kDefaultCalibrationDilutions = 8;

/// Réplicats par défaut au moment de créer une calibration.
const int kDefaultCalibrationReplicates = 3;

/// Indique si le test permet à l'utilisatrice de choisir le nombre de dilutions.
/// `false` pour les tests à plan fixe (CAT 5 points, TPC/TFC 4 points).
bool isDilutionCountConfigurable(TestDefinition test) {
  return test.code == 'DPPH' ||
      test.code == 'ABTS' ||
      test.code == 'FRAP' ||
      test.code == 'ANTIINF';
}

/// Concentrations standard pour la **courbe étalon** d'un test donné.
/// Pour DPPH/ABTS/FRAP/ANTIINF : sérige /2 paramétrable par `numDilutions`.
/// Pour CAT/TPC/TFC : plan fixe imposé par le protocole (numDilutions ignoré).
List<double> generateCalibrationConcentrations(TestDefinition test, int numDilutions) {
  switch (test.code) {
    case 'DPPH':
    case 'ABTS':
      return _halvingFromMax(1000, numDilutions);
    case 'FRAP':
      return _halvingFromMax(1, numDilutions);
    case 'CAT':
      return const [0.25, 0.40, 0.60, 0.80, 1.00];
    case 'TPC':
      return const [25, 50, 75, 100];
    case 'TFC':
      return const [25, 50, 75, 100];
    case 'ANTIINF':
      return _halvingFromMax(200, numDilutions);
    default:
      return const [];
  }
}

List<double> _halvingFromMax(double max, int count) {
  final out = <double>[];
  var v = max;
  for (var i = 0; i < count; i++) {
    out.add(v);
    v = v / 2;
  }
  return out;
}

TestDefinition? findTestByCode(String code) {
  for (final t in testsCatalog) {
    if (t.code == code) return t;
  }
  return null;
}

/// Plan d'acquisition par défaut (concentrations exprimées dans `test.concentrationUnit`).
///
/// Si l'extrait est marqué « concentré » dans sa metadata
/// (`metadata.high_concentration == true` — typiquement les huiles
/// essentielles), on bascule vers le profil HE-like (concentrations plus
/// élevées). Sinon, profil EXT-like par défaut.
List<double> defaultConcentrationsFor(
    TestDefinition test, bool isHighConcentrationSample) {
  switch (test.code) {
    case 'DPPH':
    case 'ABTS':
      return const [2000, 1000, 500, 250, 125, 62.5, 31.25, 15.625];
    case 'FRAP':
      return isHighConcentrationSample
          ? const [100, 50, 25, 12.5, 6.25, 3.125, 1.5625, 0.78125]
          : const [2, 1, 0.5, 0.25, 0.125, 0.0625, 0.03125, 0.015625];
    case 'CAT':
      return isHighConcentrationSample ? const [10.0] : const [2.0];
    case 'TPC':
      return const [200];
    case 'TFC':
      return const [800];
    case 'ANTIBAC':
      // Source: calepin manuscrit (corrigé 250 → 0.24 µl/mL, dilution /2 sur 11 puits)
      return const [
        250, 125, 62.5, 31.25, 15.625, 7.8125, 3.90625, 1.953125,
        0.9765625, 0.48828125, 0.244140625,
      ];
    case 'ANTIINF':
      return const [1000, 500, 250, 125, 62.5, 31.25];
    default:
      return const [];
  }
}

String formatConcentration(double value, String unit) {
  if (value >= 100) return '${value.toStringAsFixed(0)} $unit';
  if (value >= 1) return '${value.toStringAsFixed(2)} $unit';
  if (value >= 0.01) return '${value.toStringAsFixed(3)} $unit';
  return '${value.toStringAsFixed(5)} $unit';
}

class SessionStatus {
  static const active = 'active';
  static const completed = 'completed';
  static const aborted = 'aborted';
}
