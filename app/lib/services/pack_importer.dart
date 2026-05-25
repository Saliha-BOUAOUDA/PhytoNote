import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';
import '../theme.dart';

/// Manifeste d'un Starter Pack JSON livré dans `assets/starter_packs/`.
class StarterPack {
  final String assetPath;
  final String name;
  final String description;
  final CatalogCategory category;
  final int entryCount;

  const StarterPack({
    required this.assetPath,
    required this.name,
    required this.description,
    required this.category,
    required this.entryCount,
  });
}

/// Liste statique des packs disponibles. Mise à jour manuellement quand on
/// ajoute un nouveau JSON dans `assets/starter_packs/`.
const _packsManifest = <_PackEntry>[
  _PackEntry('extracts_solvents.json', CatalogCategory.extract),
  _PackEntry('standards_antioxidant.json', CatalogCategory.standard),
  _PackEntry('standards_antibacterial.json', CatalogCategory.standard),
  _PackEntry('standards_antiinflammatory.json', CatalogCategory.standard),
  _PackEntry('bacteria_standard.json', CatalogCategory.bacteria),
  _PackEntry('bacteria_eskape.json', CatalogCategory.bacteria),
  _PackEntry('bacteria_foodborne.json', CatalogCategory.bacteria),
  _PackEntry('bacteria_other.json', CatalogCategory.bacteria),
  _PackEntry('enzymes_antidiabetic.json', CatalogCategory.enzyme),
  _PackEntry('enzymes_antiinflammatory.json', CatalogCategory.enzyme),
  _PackEntry('enzymes_other.json', CatalogCategory.enzyme),
];

class _PackEntry {
  final String file;
  final CatalogCategory category;
  const _PackEntry(this.file, this.category);
}

class PackImportResult {
  final int imported;
  final int skipped;
  PackImportResult(this.imported, this.skipped);
}

Future<List<StarterPack>> loadAvailablePacks() async {
  final out = <StarterPack>[];
  for (final p in _packsManifest) {
    try {
      final raw = await rootBundle.loadString('assets/starter_packs/${p.file}');
      final data = jsonDecode(raw) as Map<String, Object?>;
      out.add(StarterPack(
        assetPath: 'assets/starter_packs/${p.file}',
        name: data['name'] as String? ?? p.file,
        description: data['description'] as String? ?? '',
        category: p.category,
        entryCount: (data['entries'] as List?)?.length ?? 0,
      ));
    } catch (_) {
      // Pack absent ou invalide — silencieux, on continue.
    }
  }
  return out;
}

/// Importe un pack JSON dans la base. Pour chaque entrée, vérifie qu'aucune
/// entité avec la même `abbreviation` n'existe déjà dans la catégorie cible —
/// si oui, on skippe (l'utilisateur l'a peut-être customisée).
Future<PackImportResult> importPack(
    StarterPack pack, CatalogRepository repo) async {
  final raw = await rootBundle.loadString(pack.assetPath);
  final data = jsonDecode(raw) as Map<String, Object?>;
  final entries = (data['entries'] as List?) ?? const [];
  int imported = 0;
  int skipped = 0;
  for (final entry in entries) {
    final m = entry as Map<String, Object?>;
    final abbr = (m['abbreviation'] as String?)?.trim() ?? '';
    final name = (m['name'] as String?)?.trim() ?? '';
    final customCodeRaw = (m['custom_code'] as String?)?.trim();
    final customCode = (customCodeRaw == null || customCodeRaw.isEmpty) ? null : customCodeRaw;
    final metadata = (m['metadata'] as Map?)?.cast<String, Object?>() ?? const {};
    if (abbr.isEmpty || name.isEmpty) {
      continue;
    }
    final inserted = await _insertIfMissing(
      repo: repo,
      category: pack.category,
      abbreviation: abbr,
      name: name,
      customCode: customCode,
      metadata: metadata,
    );
    if (inserted) {
      imported++;
    } else {
      skipped++;
    }
  }
  return PackImportResult(imported, skipped);
}

Future<bool> _insertIfMissing({
  required CatalogRepository repo,
  required CatalogCategory category,
  required String abbreviation,
  required String name,
  required String? customCode,
  required Map<String, Object?> metadata,
}) async {
  switch (category) {
    case CatalogCategory.plant:
      if (await repo.findPlantByAbbreviation(abbreviation) != null) return false;
      await repo.upsertPlant(Plant(
        customCode: customCode,
        abbreviation: abbreviation,
        name: name,
        metadata: metadata,
      ));
      return true;
    case CatalogCategory.extract:
      if (await repo.findExtractByAbbreviation(abbreviation) != null) return false;
      await repo.upsertExtract(Extract(
        customCode: customCode,
        abbreviation: abbreviation,
        name: name,
        metadata: metadata,
      ));
      return true;
    case CatalogCategory.standard:
      if (await repo.findStandardByAbbreviation(abbreviation) != null) return false;
      await repo.upsertStandard(Standard(
        customCode: customCode,
        abbreviation: abbreviation,
        name: name,
        metadata: metadata,
      ));
      return true;
    case CatalogCategory.bacteria:
      if (await repo.findBacteriaByAbbreviation(abbreviation) != null) return false;
      await repo.upsertBacteria(Bacteria(
        customCode: customCode,
        abbreviation: abbreviation,
        name: name,
        metadata: metadata,
      ));
      return true;
    case CatalogCategory.enzyme:
      if (await repo.findEnzymeByAbbreviation(abbreviation) != null) return false;
      await repo.upsertEnzyme(Enzyme(
        customCode: customCode,
        abbreviation: abbreviation,
        name: name,
        metadata: metadata,
      ));
      return true;
  }
}

/// Affiche un picker de Starter Pack — l'utilisateur choisit dans la liste,
/// le pack sélectionné est importé, et le résultat est retourné.
Future<PackImportResult?> showStarterPackPicker(
    BuildContext context, CatalogRepository repo) async {
  final packs = await loadAvailablePacks();
  if (!context.mounted) return null;
  final selected = await showModalBottomSheet<StarterPack>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _PackPickerSheet(packs: packs),
  );
  if (selected == null) return null;
  return importPack(selected, repo);
}

class _PackPickerSheet extends StatelessWidget {
  const _PackPickerSheet({required this.packs});
  final List<StarterPack> packs;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Importer un Starter Pack',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
              'Les entrées déjà présentes (par abréviation) sont conservées telles quelles.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (packs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Aucun pack disponible.', textAlign: TextAlign.center),
              )
            else
              for (final pack in packs) ...[
                _PackTile(pack: pack, onTap: () => Navigator.of(context).pop(pack)),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }
}

class _PackTile extends StatelessWidget {
  const _PackTile({required this.pack, required this.onTap});
  final StarterPack pack;
  final VoidCallback onTap;

  IconData get _icon {
    switch (pack.category) {
      case CatalogCategory.plant:
        return Icons.eco_rounded;
      case CatalogCategory.extract:
        return Icons.water_drop_outlined;
      case CatalogCategory.standard:
        return Icons.straighten_outlined;
      case CatalogCategory.bacteria:
        return Icons.bug_report_outlined;
      case CatalogCategory.enzyme:
        return Icons.science_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: AppColors.primaryDark, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(pack.name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                        Text('${pack.entryCount} entrées',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(pack.description,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
