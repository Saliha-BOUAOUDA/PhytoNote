import 'dart:convert';

/// Schéma uniforme des 5 entités du catalogue (plants, extracts, standards,
/// bacteria, enzymes). Chaque entité partage les mêmes colonnes — seules les
/// méta-données varient (sérialisées en JSON dans `metadata`).
///
/// Convention :
/// - `id` : clé technique stable (INTEGER autoincrement DB-side)
/// - `customCode` : code court défini par l'utilisateur (optionnel, ex. « RP »
///   pour préserver l'anonymat des plantes devant des collègues)
/// - `abbreviation` : forme jargon scientifique (« MeOH », « AChE »,
///   « *E. coli* »). C'est le label affiché en gras dans l'UI.
/// - `name` : nom complet pour le sous-titre.
/// - `metadata` : champs spécifiques à la catégorie, sérialisés en JSON.
abstract class CatalogEntry {
  int? get id;
  String? get customCode;
  String get abbreviation;
  String get name;
  Map<String, Object?> get metadata;
  bool get isArchived;

  /// Label affiché en gras / titre dans l'UI. Préfère le `customCode` si
  /// défini (le côté « secret » voulu par l'utilisateur), sinon l'abréviation.
  String get displayCode =>
      (customCode != null && customCode!.trim().isNotEmpty) ? customCode! : abbreviation;
}

String? _str(Object? v) => v == null ? null : v as String;
int? _intOrNull(Object? v) => v == null ? null : v as int;

Map<String, Object?> _decodeMeta(Object? raw) {
  if (raw == null) return const {};
  final str = raw as String;
  if (str.trim().isEmpty) return const {};
  final out = jsonDecode(str);
  return (out as Map).cast<String, Object?>();
}

String _encodeMeta(Map<String, Object?> meta) =>
    meta.isEmpty ? '{}' : jsonEncode(meta);

class Plant implements CatalogEntry {
  @override
  final int? id;
  @override
  final String? customCode;
  @override
  final String abbreviation;
  @override
  final String name;
  @override
  final Map<String, Object?> metadata;
  @override
  final bool isArchived;

  const Plant({
    this.id,
    this.customCode,
    required this.abbreviation,
    required this.name,
    this.metadata = const {},
    this.isArchived = false,
  });

  String? get scientificName => _str(metadata['scientific_name']);
  String? get family => _str(metadata['family']);
  String? get organ => _str(metadata['organ']);
  String? get notes => _str(metadata['notes']);

  String get fullName => scientificName == null || scientificName!.isEmpty
      ? name
      : '$name ($scientificName)';

  Plant copyWith({
    int? id,
    String? customCode,
    String? abbreviation,
    String? name,
    Map<String, Object?>? metadata,
    bool? isArchived,
  }) =>
      Plant(
        id: id ?? this.id,
        customCode: customCode ?? this.customCode,
        abbreviation: abbreviation ?? this.abbreviation,
        name: name ?? this.name,
        metadata: metadata ?? this.metadata,
        isArchived: isArchived ?? this.isArchived,
      );

  @override
  String get displayCode =>
      (customCode != null && customCode!.trim().isNotEmpty) ? customCode! : abbreviation;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'custom_code': customCode,
        'abbreviation': abbreviation,
        'name': name,
        'metadata': _encodeMeta(metadata),
        'is_archived': isArchived ? 1 : 0,
      };

  static Plant fromMap(Map<String, Object?> m) => Plant(
        id: _intOrNull(m['id']),
        customCode: _str(m['custom_code']),
        abbreviation: m['abbreviation'] as String,
        name: m['name'] as String,
        metadata: _decodeMeta(m['metadata']),
        isArchived: (m['is_archived'] as int? ?? 0) != 0,
      );
}

class Extract implements CatalogEntry {
  @override
  final int? id;
  @override
  final String? customCode;
  @override
  final String abbreviation;
  @override
  final String name;
  @override
  final Map<String, Object?> metadata;
  @override
  final bool isArchived;

  const Extract({
    this.id,
    this.customCode,
    required this.abbreviation,
    required this.name,
    this.metadata = const {},
    this.isArchived = false,
  });

  /// Polarité documentée (très polaire, polaire, intermédiaire, apolaire,
  /// très apolaire, variable). Texte libre — informatif uniquement.
  String? get polarity => _str(metadata['polarity']);
  String? get notes => _str(metadata['notes']);

  /// Indique un extrait à concentrations « hautes » (huiles essentielles,
  /// extraits concentrés). Détermine les concentrations par défaut côté
  /// session : profil HE-like vs profil EXT-like (cf. defaults dans
  /// `config/catalog.dart#defaultConcentrationsFor`).
  bool get isHighConcentrationSample => metadata['high_concentration'] == true;

  Extract copyWith({
    int? id,
    String? customCode,
    String? abbreviation,
    String? name,
    Map<String, Object?>? metadata,
    bool? isArchived,
  }) =>
      Extract(
        id: id ?? this.id,
        customCode: customCode ?? this.customCode,
        abbreviation: abbreviation ?? this.abbreviation,
        name: name ?? this.name,
        metadata: metadata ?? this.metadata,
        isArchived: isArchived ?? this.isArchived,
      );

  @override
  String get displayCode =>
      (customCode != null && customCode!.trim().isNotEmpty) ? customCode! : abbreviation;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'custom_code': customCode,
        'abbreviation': abbreviation,
        'name': name,
        'metadata': _encodeMeta(metadata),
        'is_archived': isArchived ? 1 : 0,
      };

  static Extract fromMap(Map<String, Object?> m) => Extract(
        id: _intOrNull(m['id']),
        customCode: _str(m['custom_code']),
        abbreviation: m['abbreviation'] as String,
        name: m['name'] as String,
        metadata: _decodeMeta(m['metadata']),
        isArchived: (m['is_archived'] as int? ?? 0) != 0,
      );
}

class Standard implements CatalogEntry {
  @override
  final int? id;
  @override
  final String? customCode;
  @override
  final String abbreviation;
  @override
  final String name;
  @override
  final Map<String, Object?> metadata;
  @override
  final bool isArchived;

  const Standard({
    this.id,
    this.customCode,
    required this.abbreviation,
    required this.name,
    this.metadata = const {},
    this.isArchived = false,
  });

  /// Label des équivalents (ex. AAE, GAE, TE) utilisé dans les calculs et
  /// les exports Excel.
  String get equivalentLabel =>
      _str(metadata['equivalent_label']) ?? '${abbreviation}eq';

  String? get chemblId => _str(metadata['chembl_id']);
  double? get molarMassGperMol {
    final v = metadata['molar_mass_g_per_mol'];
    if (v is num) return v.toDouble();
    return null;
  }

  String? get notes => _str(metadata['notes']);

  Standard copyWith({
    int? id,
    String? customCode,
    String? abbreviation,
    String? name,
    Map<String, Object?>? metadata,
    bool? isArchived,
  }) =>
      Standard(
        id: id ?? this.id,
        customCode: customCode ?? this.customCode,
        abbreviation: abbreviation ?? this.abbreviation,
        name: name ?? this.name,
        metadata: metadata ?? this.metadata,
        isArchived: isArchived ?? this.isArchived,
      );

  @override
  String get displayCode =>
      (customCode != null && customCode!.trim().isNotEmpty) ? customCode! : abbreviation;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'custom_code': customCode,
        'abbreviation': abbreviation,
        'name': name,
        'metadata': _encodeMeta(metadata),
        'is_archived': isArchived ? 1 : 0,
      };

  static Standard fromMap(Map<String, Object?> m) => Standard(
        id: _intOrNull(m['id']),
        customCode: _str(m['custom_code']),
        abbreviation: m['abbreviation'] as String,
        name: m['name'] as String,
        metadata: _decodeMeta(m['metadata']),
        isArchived: (m['is_archived'] as int? ?? 0) != 0,
      );
}

class Bacteria implements CatalogEntry {
  @override
  final int? id;
  @override
  final String? customCode;
  @override
  final String abbreviation;
  @override
  final String name;
  @override
  final Map<String, Object?> metadata;
  @override
  final bool isArchived;

  const Bacteria({
    this.id,
    this.customCode,
    required this.abbreviation,
    required this.name,
    this.metadata = const {},
    this.isArchived = false,
  });

  /// Gram +, − ou texte libre (« levure » pour C. albicans).
  String get gram => _str(metadata['gram']) ?? '?';
  String? get atccSuggested => _str(metadata['atcc_suggested']);
  String? get notes => _str(metadata['notes']);

  Bacteria copyWith({
    int? id,
    String? customCode,
    String? abbreviation,
    String? name,
    Map<String, Object?>? metadata,
    bool? isArchived,
  }) =>
      Bacteria(
        id: id ?? this.id,
        customCode: customCode ?? this.customCode,
        abbreviation: abbreviation ?? this.abbreviation,
        name: name ?? this.name,
        metadata: metadata ?? this.metadata,
        isArchived: isArchived ?? this.isArchived,
      );

  @override
  String get displayCode =>
      (customCode != null && customCode!.trim().isNotEmpty) ? customCode! : abbreviation;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'custom_code': customCode,
        'abbreviation': abbreviation,
        'name': name,
        'metadata': _encodeMeta(metadata),
        'is_archived': isArchived ? 1 : 0,
      };

  static Bacteria fromMap(Map<String, Object?> m) => Bacteria(
        id: _intOrNull(m['id']),
        customCode: _str(m['custom_code']),
        abbreviation: m['abbreviation'] as String,
        name: m['name'] as String,
        metadata: _decodeMeta(m['metadata']),
        isArchived: (m['is_archived'] as int? ?? 0) != 0,
      );
}

class Enzyme implements CatalogEntry {
  @override
  final int? id;
  @override
  final String? customCode;
  @override
  final String abbreviation;
  @override
  final String name;
  @override
  final Map<String, Object?> metadata;
  @override
  final bool isArchived;

  const Enzyme({
    this.id,
    this.customCode,
    required this.abbreviation,
    required this.name,
    this.metadata = const {},
    this.isArchived = false,
  });

  String? get ecNumber => _str(metadata['ec_number']);
  String? get chemblId => _str(metadata['chembl_id']);
  String? get notes => _str(metadata['notes']);

  List<String> get applicableTests {
    final raw = metadata['applicable_tests'];
    if (raw is List) return raw.cast<String>();
    if (raw is String) {
      return raw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  Enzyme copyWith({
    int? id,
    String? customCode,
    String? abbreviation,
    String? name,
    Map<String, Object?>? metadata,
    bool? isArchived,
  }) =>
      Enzyme(
        id: id ?? this.id,
        customCode: customCode ?? this.customCode,
        abbreviation: abbreviation ?? this.abbreviation,
        name: name ?? this.name,
        metadata: metadata ?? this.metadata,
        isArchived: isArchived ?? this.isArchived,
      );

  @override
  String get displayCode =>
      (customCode != null && customCode!.trim().isNotEmpty) ? customCode! : abbreviation;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'custom_code': customCode,
        'abbreviation': abbreviation,
        'name': name,
        'metadata': _encodeMeta(metadata),
        'is_archived': isArchived ? 1 : 0,
      };

  static Enzyme fromMap(Map<String, Object?> m) => Enzyme(
        id: _intOrNull(m['id']),
        customCode: _str(m['custom_code']),
        abbreviation: m['abbreviation'] as String,
        name: m['name'] as String,
        metadata: _decodeMeta(m['metadata']),
        isArchived: (m['is_archived'] as int? ?? 0) != 0,
      );
}

/// Liste des catégories du catalogue. Ordre = ordre des onglets dans l'UI.
enum CatalogCategory {
  plant('plants', 'Plantes'),
  extract('extracts', 'Extraits'),
  standard('standards', 'Standards'),
  bacteria('bacteria', 'Bactéries'),
  enzyme('enzymes', 'Enzymes');

  final String table;
  final String label;
  const CatalogCategory(this.table, this.label);
}
