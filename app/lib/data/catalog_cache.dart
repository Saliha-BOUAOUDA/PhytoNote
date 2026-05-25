import 'catalog_models.dart';
import 'catalog_repository.dart';

/// Cache global synchrone des entités du catalogue. Rempli au boot par
/// `CatalogCache.refresh()` et après chaque édition depuis `CatalogScreen`.
///
/// Permet aux écrans de session (saisie en condition lab, performance critique)
/// de lookup `Plant`/`Extract`/etc. par id sans aller-retour async vers SQLite.
class CatalogCache {
  CatalogCache._();

  static List<Plant> plants = const [];
  static List<Extract> extracts = const [];
  static List<Standard> standards = const [];
  static List<Bacteria> bacteria = const [];
  static List<Enzyme> enzymes = const [];

  static Future<void> refresh() async {
    final repo = CatalogRepository();
    plants = await repo.listPlants(includeArchived: true);
    extracts = await repo.listExtracts(includeArchived: true);
    standards = await repo.listStandards(includeArchived: true);
    bacteria = await repo.listBacteria(includeArchived: true);
    enzymes = await repo.listEnzymes(includeArchived: true);
  }

  // ---------- Lookups par id ----------
  static Plant? findPlant(int? id) =>
      id == null ? null : plants.where((e) => e.id == id).firstOrNull;
  static Extract? findExtract(int? id) =>
      id == null ? null : extracts.where((e) => e.id == id).firstOrNull;
  static Standard? findStandard(int? id) =>
      id == null ? null : standards.where((e) => e.id == id).firstOrNull;
  static Bacteria? findBacteria(int? id) =>
      id == null ? null : bacteria.where((e) => e.id == id).firstOrNull;
  static Enzyme? findEnzyme(int? id) =>
      id == null ? null : enzymes.where((e) => e.id == id).firstOrNull;

  // ---------- Lookups par abréviation (pour starter packs / import) ----------
  static Plant? findPlantByAbbr(String abbr) =>
      plants.where((e) => e.abbreviation == abbr).firstOrNull;
  static Extract? findExtractByAbbr(String abbr) =>
      extracts.where((e) => e.abbreviation == abbr).firstOrNull;
  static Standard? findStandardByAbbr(String abbr) =>
      standards.where((e) => e.abbreviation == abbr).firstOrNull;
  static Bacteria? findBacteriaByAbbr(String abbr) =>
      bacteria.where((e) => e.abbreviation == abbr).firstOrNull;
  static Enzyme? findEnzymeByAbbr(String abbr) =>
      enzymes.where((e) => e.abbreviation == abbr).firstOrNull;

  static List<Plant> activePlants() =>
      plants.where((e) => !e.isArchived).toList();
  static List<Extract> activeExtracts() =>
      extracts.where((e) => !e.isArchived).toList();
  static List<Standard> activeStandards() =>
      standards.where((e) => !e.isArchived).toList();
  static List<Bacteria> activeBacteria() =>
      bacteria.where((e) => !e.isArchived).toList();
  static List<Enzyme> activeEnzymes() =>
      enzymes.where((e) => !e.isArchived).toList();

  static bool get isEmpty =>
      plants.isEmpty &&
      extracts.isEmpty &&
      standards.isEmpty &&
      bacteria.isEmpty &&
      enzymes.isEmpty;
}
