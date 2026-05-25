import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/catalog_cache.dart';
import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';
import '../services/pack_importer.dart';
import '../theme.dart';
import '../widgets/scientific_label.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> with SingleTickerProviderStateMixin {
  final _repo = CatalogRepository();
  late final TabController _tab;

  List<Plant> _plants = const [];
  List<Extract> _extracts = const [];
  List<Standard> _standards = const [];
  List<Bacteria> _bacteria = const [];
  List<Enzyme> _enzymes = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _tab.addListener(() => setState(() {}));
    _refresh();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final plants = await _repo.listPlants(includeArchived: true);
    final extracts = await _repo.listExtracts(includeArchived: true);
    final standards = await _repo.listStandards(includeArchived: true);
    final bacteria = await _repo.listBacteria(includeArchived: true);
    final enzymes = await _repo.listEnzymes(includeArchived: true);
    if (!mounted) return;
    setState(() {
      _plants = plants;
      _extracts = extracts;
      _standards = standards;
      _bacteria = bacteria;
      _enzymes = enzymes;
      _loading = false;
    });
    await CatalogCache.refresh();
  }

  CatalogCategory _categoryAt(int idx) {
    switch (idx) {
      case 0:
        return CatalogCategory.plant;
      case 1:
        return CatalogCategory.extract;
      case 2:
        return CatalogCategory.standard;
      case 3:
        return CatalogCategory.bacteria;
      case 4:
        return CatalogCategory.enzyme;
      default:
        return CatalogCategory.plant;
    }
  }

  Future<void> _onAdd(int idx) async {
    final cat = _categoryAt(idx);
    switch (cat) {
      case CatalogCategory.plant:
        await showPlantEditSheet(context, _repo, null);
        break;
      case CatalogCategory.extract:
        await showExtractEditSheet(context, _repo, null);
        break;
      case CatalogCategory.standard:
        await showStandardEditSheet(context, _repo, null);
        break;
      case CatalogCategory.bacteria:
        await showBacteriaEditSheet(context, _repo, null);
        break;
      case CatalogCategory.enzyme:
        await showEnzymeEditSheet(context, _repo, null);
        break;
    }
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _onImportPack() async {
    final result = await showStarterPackPicker(context, _repo);
    if (result != null && mounted) {
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.imported} entrée(s) importée(s) · ${result.skipped} déjà présente(s)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogue'),
        actions: [
          IconButton(
            tooltip: 'Importer un Starter Pack',
            icon: const Icon(Icons.download_rounded),
            onPressed: _loading ? null : _onImportPack,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tab,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.primaryDark,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Plantes (${_plants.length})'),
              Tab(text: 'Extraits (${_extracts.length})'),
              Tab(text: 'Standards (${_standards.length})'),
              Tab(text: 'Bactéries (${_bacteria.length})'),
              Tab(text: 'Enzymes (${_enzymes.length})'),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _PlantList(plants: _plants, repo: _repo, onChanged: _refresh),
                _ExtractList(extracts: _extracts, repo: _repo, onChanged: _refresh),
                _StandardList(standards: _standards, repo: _repo, onChanged: _refresh),
                _BacteriaList(bacteria: _bacteria, repo: _repo, onChanged: _refresh),
                _EnzymeList(enzymes: _enzymes, repo: _repo, onChanged: _refresh),
              ],
            ),
      floatingActionButton: _loading ? null : _buildFab(),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded),
      label: Text(_addLabel(_tab.index), style: const TextStyle(fontWeight: FontWeight.w700)),
      onPressed: () => _onAdd(_tab.index),
    );
  }

  String _addLabel(int idx) {
    switch (idx) {
      case 0:
        return 'Plante';
      case 1:
        return 'Extrait';
      case 2:
        return 'Standard';
      case 3:
        return 'Bactérie';
      case 4:
        return 'Enzyme';
      default:
        return '';
    }
  }
}

// ---------------------------------------------------------------------------
// LISTS
// ---------------------------------------------------------------------------

class _PlantList extends StatelessWidget {
  const _PlantList({required this.plants, required this.repo, required this.onChanged});

  final List<Plant> plants;
  final CatalogRepository repo;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (plants.isEmpty) {
      return const _EmptyState(label: 'Aucune plante. Tape « + Plante » ou importe un Starter Pack.');
    }
    return RefreshIndicator(
      onRefresh: () async => onChanged(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: plants.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final p = plants[i];
          return _CatalogTile(
            displayCode: p.displayCode,
            abbreviation: p.abbreviation,
            title: p.name,
            subtitle: [
              if (p.scientificName != null && p.scientificName!.isNotEmpty)
                p.scientificName!,
              if (p.organ != null && p.organ!.isNotEmpty) 'organe : ${p.organ}',
              if (p.family != null && p.family!.isNotEmpty) 'famille : ${p.family}',
            ].join(' · '),
            isArchived: p.isArchived,
            onTap: () async {
              await showPlantEditSheet(context, repo, p);
              onChanged();
            },
          );
        },
      ),
    );
  }
}

class _ExtractList extends StatelessWidget {
  const _ExtractList({required this.extracts, required this.repo, required this.onChanged});

  final List<Extract> extracts;
  final CatalogRepository repo;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (extracts.isEmpty) {
      return const _EmptyState(label: 'Aucun extrait. Tape « + Extrait » ou importe le pack « Solvants courants ».');
    }
    return RefreshIndicator(
      onRefresh: () async => onChanged(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: extracts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final e = extracts[i];
          return _CatalogTile(
            displayCode: e.displayCode,
            abbreviation: e.abbreviation,
            title: e.name,
            subtitle: [
              if (e.polarity != null) 'polarité : ${e.polarity}',
              if (e.isHighConcentrationSample) 'échantillon concentré (HE-like)',
            ].join(' · '),
            isArchived: e.isArchived,
            onTap: () async {
              await showExtractEditSheet(context, repo, e);
              onChanged();
            },
          );
        },
      ),
    );
  }
}

class _StandardList extends StatelessWidget {
  const _StandardList({required this.standards, required this.repo, required this.onChanged});

  final List<Standard> standards;
  final CatalogRepository repo;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (standards.isEmpty) {
      return const _EmptyState(label: 'Aucun standard. Tape « + Standard » ou importe un Starter Pack.');
    }
    return RefreshIndicator(
      onRefresh: () async => onChanged(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: standards.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final s = standards[i];
          return _CatalogTile(
            displayCode: s.displayCode,
            abbreviation: s.abbreviation,
            title: s.name,
            subtitle: [
              'éq. ${s.equivalentLabel}',
              if (s.chemblId != null && s.chemblId!.isNotEmpty) s.chemblId!,
              if (s.molarMassGperMol != null) '${s.molarMassGperMol!.toStringAsFixed(2)} g/mol',
            ].join(' · '),
            isArchived: s.isArchived,
            onTap: () async {
              await showStandardEditSheet(context, repo, s);
              onChanged();
            },
          );
        },
      ),
    );
  }
}

class _BacteriaList extends StatelessWidget {
  const _BacteriaList({required this.bacteria, required this.repo, required this.onChanged});

  final List<Bacteria> bacteria;
  final CatalogRepository repo;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (bacteria.isEmpty) {
      return const _EmptyState(label: 'Aucune bactérie. Importe le pack « Antibactérien standard » pour démarrer.');
    }
    return RefreshIndicator(
      onRefresh: () async => onChanged(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: bacteria.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final b = bacteria[i];
          return _CatalogTile(
            displayCode: b.displayCode,
            abbreviation: b.abbreviation,
            italicAbbreviation: true,
            title: b.name,
            italicTitle: true,
            subtitle: [
              'Gram ${b.gram}',
              if (b.atccSuggested != null && b.atccSuggested!.isNotEmpty) b.atccSuggested!,
            ].join(' · '),
            isArchived: b.isArchived,
            onTap: () async {
              await showBacteriaEditSheet(context, repo, b);
              onChanged();
            },
          );
        },
      ),
    );
  }
}

class _EnzymeList extends StatelessWidget {
  const _EnzymeList({required this.enzymes, required this.repo, required this.onChanged});

  final List<Enzyme> enzymes;
  final CatalogRepository repo;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (enzymes.isEmpty) {
      return const _EmptyState(label: 'Aucune enzyme. Importe un pack (antidiabétique, anti-inflammatoire…).');
    }
    return RefreshIndicator(
      onRefresh: () async => onChanged(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: enzymes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final e = enzymes[i];
          return _CatalogTile(
            displayCode: e.displayCode,
            abbreviation: e.abbreviation,
            title: e.name,
            subtitle: [
              if (e.ecNumber != null && e.ecNumber!.isNotEmpty) 'EC ${e.ecNumber}',
              if (e.chemblId != null && e.chemblId!.isNotEmpty) e.chemblId!,
              if (e.applicableTests.isNotEmpty) 'tests : ${e.applicableTests.join(", ")}',
            ].join(' · '),
            isArchived: e.isArchived,
            onTap: () async {
              await showEnzymeEditSheet(context, repo, e);
              onChanged();
            },
          );
        },
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.displayCode,
    required this.abbreviation,
    required this.title,
    required this.subtitle,
    required this.isArchived,
    required this.onTap,
    this.italicAbbreviation = false,
    this.italicTitle = false,
  });

  final String displayCode;
  final String abbreviation;
  final String title;
  final String subtitle;
  final bool isArchived;
  final VoidCallback onTap;
  final bool italicAbbreviation;
  final bool italicTitle;

  @override
  Widget build(BuildContext context) {
    final showCustomCode = displayCode != abbreviation;
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: isArchived ? 0.5 : 1,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                Container(
                  constraints: const BoxConstraints(minWidth: 60),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ScientificLabel(
                    text: showCustomCode ? displayCode : abbreviation,
                    italic: !showCustomCode && italicAbbreviation,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ScientificLabel(
                              text: title,
                              italic: italicTitle,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (showCustomCode) ...[
                            const SizedBox(width: 6),
                            Text(
                              abbreviation,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ],
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (isArchived)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.archive_outlined, size: 18, color: AppColors.textMuted),
                  ),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(label,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EDIT SHEETS
// ---------------------------------------------------------------------------

Future<void> showPlantEditSheet(
    BuildContext context, CatalogRepository repo, Plant? existing) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _PlantEditSheet(repo: repo, existing: existing),
  );
}

Future<void> showExtractEditSheet(
    BuildContext context, CatalogRepository repo, Extract? existing) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ExtractEditSheet(repo: repo, existing: existing),
  );
}

Future<void> showStandardEditSheet(
    BuildContext context, CatalogRepository repo, Standard? existing) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _StandardEditSheet(repo: repo, existing: existing),
  );
}

Future<void> showBacteriaEditSheet(
    BuildContext context, CatalogRepository repo, Bacteria? existing) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _BacteriaEditSheet(repo: repo, existing: existing),
  );
}

Future<void> showEnzymeEditSheet(
    BuildContext context, CatalogRepository repo, Enzyme? existing) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _EnzymeEditSheet(repo: repo, existing: existing),
  );
}

// --- Plant ---------------------------------------------------------------

class _PlantEditSheet extends StatefulWidget {
  const _PlantEditSheet({required this.repo, required this.existing});
  final CatalogRepository repo;
  final Plant? existing;

  @override
  State<_PlantEditSheet> createState() => _PlantEditSheetState();
}

class _PlantEditSheetState extends State<_PlantEditSheet> {
  final _customCodeCtrl = TextEditingController();
  final _abbrCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _scientificCtrl = TextEditingController();
  final _organCtrl = TextEditingController();
  final _familyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isArchived = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    if (p != null) {
      _customCodeCtrl.text = p.customCode ?? '';
      _abbrCtrl.text = p.abbreviation;
      _nameCtrl.text = p.name;
      _scientificCtrl.text = p.scientificName ?? '';
      _organCtrl.text = p.organ ?? '';
      _familyCtrl.text = p.family ?? '';
      _notesCtrl.text = p.notes ?? '';
      _isArchived = p.isArchived;
    }
  }

  @override
  void dispose() {
    _customCodeCtrl.dispose();
    _abbrCtrl.dispose();
    _nameCtrl.dispose();
    _scientificCtrl.dispose();
    _organCtrl.dispose();
    _familyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final abbr = _abbrCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (abbr.isEmpty || name.isEmpty) return;
    final p = Plant(
      id: widget.existing?.id,
      customCode: _customCodeCtrl.text.trim().isEmpty ? null : _customCodeCtrl.text.trim(),
      abbreviation: abbr,
      name: name,
      metadata: {
        if (_scientificCtrl.text.trim().isNotEmpty) 'scientific_name': _scientificCtrl.text.trim(),
        if (_organCtrl.text.trim().isNotEmpty) 'organ': _organCtrl.text.trim(),
        if (_familyCtrl.text.trim().isNotEmpty) 'family': _familyCtrl.text.trim(),
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      },
      isArchived: _isArchived,
    );
    await widget.repo.upsertPlant(p);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final id = widget.existing?.id;
    if (id == null) return;
    await widget.repo.deletePlant(id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return _EditSheetScaffold(
      title: widget.existing == null ? 'Nouvelle plante' : 'Éditer la plante',
      onSave: _save,
      onDelete: widget.existing == null ? null : _delete,
      isArchived: _isArchived,
      onArchiveToggle: (v) => setState(() => _isArchived = v),
      children: [
        _Field(controller: _customCodeCtrl, label: 'Code custom (secret, optionnel)', hint: 'ex. RP, P1, A2…'),
        _Field(controller: _abbrCtrl, label: 'Abréviation *', hint: 'ex. Romarin, Origanum'),
        _Field(controller: _nameCtrl, label: 'Nom complet (commun) *', hint: 'ex. Romarin'),
        _Field(controller: _scientificCtrl, label: 'Nom scientifique', hint: 'ex. Rosmarinus officinalis', italic: true),
        _Field(controller: _organCtrl, label: 'Organe', hint: 'feuille, fleur, racine…'),
        _Field(controller: _familyCtrl, label: 'Famille', hint: 'Lamiaceae'),
        _Field(controller: _notesCtrl, label: 'Notes', maxLines: 3),
      ],
    );
  }
}

// --- Extract -------------------------------------------------------------

class _ExtractEditSheet extends StatefulWidget {
  const _ExtractEditSheet({required this.repo, required this.existing});
  final CatalogRepository repo;
  final Extract? existing;

  @override
  State<_ExtractEditSheet> createState() => _ExtractEditSheetState();
}

class _ExtractEditSheetState extends State<_ExtractEditSheet> {
  final _customCodeCtrl = TextEditingController();
  final _abbrCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _polarityCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isHighConcentration = false;
  bool _isArchived = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _customCodeCtrl.text = e.customCode ?? '';
      _abbrCtrl.text = e.abbreviation;
      _nameCtrl.text = e.name;
      _polarityCtrl.text = e.polarity ?? '';
      _notesCtrl.text = e.notes ?? '';
      _isHighConcentration = e.isHighConcentrationSample;
      _isArchived = e.isArchived;
    }
  }

  @override
  void dispose() {
    _customCodeCtrl.dispose();
    _abbrCtrl.dispose();
    _nameCtrl.dispose();
    _polarityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final abbr = _abbrCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (abbr.isEmpty || name.isEmpty) return;
    final e = Extract(
      id: widget.existing?.id,
      customCode: _customCodeCtrl.text.trim().isEmpty ? null : _customCodeCtrl.text.trim(),
      abbreviation: abbr,
      name: name,
      metadata: {
        if (_polarityCtrl.text.trim().isNotEmpty) 'polarity': _polarityCtrl.text.trim(),
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
        'high_concentration': _isHighConcentration,
      },
      isArchived: _isArchived,
    );
    await widget.repo.upsertExtract(e);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final id = widget.existing?.id;
    if (id == null) return;
    await widget.repo.deleteExtract(id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return _EditSheetScaffold(
      title: widget.existing == null ? 'Nouvel extrait' : 'Éditer l\'extrait',
      onSave: _save,
      onDelete: widget.existing == null ? null : _delete,
      isArchived: _isArchived,
      onArchiveToggle: (v) => setState(() => _isArchived = v),
      children: [
        _Field(controller: _customCodeCtrl, label: 'Code custom (optionnel)'),
        _Field(controller: _abbrCtrl, label: 'Abréviation jargon *', hint: 'ex. MeOH, EtOH, EtOAc, EO'),
        _Field(controller: _nameCtrl, label: 'Nom complet *', hint: 'ex. Extrait méthanolique'),
        _Field(controller: _polarityCtrl, label: 'Polarité', hint: 'très polaire, polaire, apolaire…'),
        _Field(controller: _notesCtrl, label: 'Notes', maxLines: 3),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Échantillon concentré (HE-like)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: const Text(
            'Active pour les huiles essentielles ou extraits à haute concentration. Influence les concentrations par défaut des manips.',
            style: TextStyle(fontSize: 12),
          ),
          value: _isHighConcentration,
          onChanged: (v) => setState(() => _isHighConcentration = v),
          activeColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

// --- Standard ------------------------------------------------------------

class _StandardEditSheet extends StatefulWidget {
  const _StandardEditSheet({required this.repo, required this.existing});
  final CatalogRepository repo;
  final Standard? existing;

  @override
  State<_StandardEditSheet> createState() => _StandardEditSheetState();
}

class _StandardEditSheetState extends State<_StandardEditSheet> {
  final _customCodeCtrl = TextEditingController();
  final _abbrCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _equivCtrl = TextEditingController();
  final _chemblCtrl = TextEditingController();
  final _massCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isArchived = false;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    if (s != null) {
      _customCodeCtrl.text = s.customCode ?? '';
      _abbrCtrl.text = s.abbreviation;
      _nameCtrl.text = s.name;
      _equivCtrl.text = s.equivalentLabel;
      _chemblCtrl.text = s.chemblId ?? '';
      _massCtrl.text = s.molarMassGperMol?.toString() ?? '';
      _notesCtrl.text = s.notes ?? '';
      _isArchived = s.isArchived;
    }
  }

  @override
  void dispose() {
    _customCodeCtrl.dispose();
    _abbrCtrl.dispose();
    _nameCtrl.dispose();
    _equivCtrl.dispose();
    _chemblCtrl.dispose();
    _massCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final abbr = _abbrCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (abbr.isEmpty || name.isEmpty) return;
    final mass = double.tryParse(_massCtrl.text.trim().replaceAll(',', '.'));
    final s = Standard(
      id: widget.existing?.id,
      customCode: _customCodeCtrl.text.trim().isEmpty ? null : _customCodeCtrl.text.trim(),
      abbreviation: abbr,
      name: name,
      metadata: {
        if (_equivCtrl.text.trim().isNotEmpty) 'equivalent_label': _equivCtrl.text.trim(),
        if (_chemblCtrl.text.trim().isNotEmpty) 'chembl_id': _chemblCtrl.text.trim(),
        if (mass != null) 'molar_mass_g_per_mol': mass,
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      },
      isArchived: _isArchived,
    );
    await widget.repo.upsertStandard(s);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final id = widget.existing?.id;
    if (id == null) return;
    await widget.repo.deleteStandard(id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return _EditSheetScaffold(
      title: widget.existing == null ? 'Nouveau standard' : 'Éditer le standard',
      onSave: _save,
      onDelete: widget.existing == null ? null : _delete,
      isArchived: _isArchived,
      onArchiveToggle: (v) => setState(() => _isArchived = v),
      children: [
        _Field(controller: _customCodeCtrl, label: 'Code custom (optionnel)'),
        _Field(controller: _abbrCtrl, label: 'Abréviation jargon *', hint: 'ex. AA, GA, TRX, CIP'),
        _Field(controller: _nameCtrl, label: 'Nom complet *', hint: 'Acide ascorbique'),
        _Field(controller: _equivCtrl, label: 'Label équivalents', hint: 'AAE, GAE, TE…'),
        _Field(controller: _chemblCtrl, label: 'ChEMBL ID', hint: 'CHEMBL196'),
        _Field(controller: _massCtrl, label: 'Masse molaire (g/mol)',
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]),
        _Field(controller: _notesCtrl, label: 'Notes', maxLines: 3),
      ],
    );
  }
}

// --- Bacteria ------------------------------------------------------------

class _BacteriaEditSheet extends StatefulWidget {
  const _BacteriaEditSheet({required this.repo, required this.existing});
  final CatalogRepository repo;
  final Bacteria? existing;

  @override
  State<_BacteriaEditSheet> createState() => _BacteriaEditSheetState();
}

class _BacteriaEditSheetState extends State<_BacteriaEditSheet> {
  final _customCodeCtrl = TextEditingController();
  final _abbrCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _gramCtrl = TextEditingController();
  final _atccCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isArchived = false;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    if (b != null) {
      _customCodeCtrl.text = b.customCode ?? '';
      _abbrCtrl.text = b.abbreviation;
      _nameCtrl.text = b.name;
      _gramCtrl.text = b.gram;
      _atccCtrl.text = b.atccSuggested ?? '';
      _notesCtrl.text = b.notes ?? '';
      _isArchived = b.isArchived;
    }
  }

  @override
  void dispose() {
    _customCodeCtrl.dispose();
    _abbrCtrl.dispose();
    _nameCtrl.dispose();
    _gramCtrl.dispose();
    _atccCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final abbr = _abbrCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (abbr.isEmpty || name.isEmpty) return;
    final b = Bacteria(
      id: widget.existing?.id,
      customCode: _customCodeCtrl.text.trim().isEmpty ? null : _customCodeCtrl.text.trim(),
      abbreviation: abbr,
      name: name,
      metadata: {
        if (_gramCtrl.text.trim().isNotEmpty) 'gram': _gramCtrl.text.trim(),
        if (_atccCtrl.text.trim().isNotEmpty) 'atcc_suggested': _atccCtrl.text.trim(),
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      },
      isArchived: _isArchived,
    );
    await widget.repo.upsertBacteria(b);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final id = widget.existing?.id;
    if (id == null) return;
    await widget.repo.deleteBacteria(id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return _EditSheetScaffold(
      title: widget.existing == null ? 'Nouvelle bactérie' : 'Éditer la bactérie',
      onSave: _save,
      onDelete: widget.existing == null ? null : _delete,
      isArchived: _isArchived,
      onArchiveToggle: (v) => setState(() => _isArchived = v),
      children: [
        _Field(controller: _customCodeCtrl, label: 'Code custom (optionnel)'),
        _Field(controller: _abbrCtrl, label: 'Abréviation scientifique *', hint: 'ex. E. coli, S. aureus', italic: true),
        _Field(controller: _nameCtrl, label: 'Nom complet *', hint: 'Escherichia coli', italic: true),
        _Field(controller: _gramCtrl, label: 'Gram', hint: '+, −, levure…'),
        _Field(controller: _atccCtrl, label: 'Souche ATCC', hint: 'ATCC 25922'),
        _Field(controller: _notesCtrl, label: 'Notes', maxLines: 3),
      ],
    );
  }
}

// --- Enzyme --------------------------------------------------------------

class _EnzymeEditSheet extends StatefulWidget {
  const _EnzymeEditSheet({required this.repo, required this.existing});
  final CatalogRepository repo;
  final Enzyme? existing;

  @override
  State<_EnzymeEditSheet> createState() => _EnzymeEditSheetState();
}

class _EnzymeEditSheetState extends State<_EnzymeEditSheet> {
  final _customCodeCtrl = TextEditingController();
  final _abbrCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _ecCtrl = TextEditingController();
  final _chemblCtrl = TextEditingController();
  final _testsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isArchived = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _customCodeCtrl.text = e.customCode ?? '';
      _abbrCtrl.text = e.abbreviation;
      _nameCtrl.text = e.name;
      _ecCtrl.text = e.ecNumber ?? '';
      _chemblCtrl.text = e.chemblId ?? '';
      _testsCtrl.text = e.applicableTests.join(', ');
      _notesCtrl.text = e.notes ?? '';
      _isArchived = e.isArchived;
    }
  }

  @override
  void dispose() {
    _customCodeCtrl.dispose();
    _abbrCtrl.dispose();
    _nameCtrl.dispose();
    _ecCtrl.dispose();
    _chemblCtrl.dispose();
    _testsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final abbr = _abbrCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (abbr.isEmpty || name.isEmpty) return;
    final tests = _testsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final e = Enzyme(
      id: widget.existing?.id,
      customCode: _customCodeCtrl.text.trim().isEmpty ? null : _customCodeCtrl.text.trim(),
      abbreviation: abbr,
      name: name,
      metadata: {
        if (_ecCtrl.text.trim().isNotEmpty) 'ec_number': _ecCtrl.text.trim(),
        if (_chemblCtrl.text.trim().isNotEmpty) 'chembl_id': _chemblCtrl.text.trim(),
        if (tests.isNotEmpty) 'applicable_tests': tests,
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      },
      isArchived: _isArchived,
    );
    await widget.repo.upsertEnzyme(e);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final id = widget.existing?.id;
    if (id == null) return;
    await widget.repo.deleteEnzyme(id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return _EditSheetScaffold(
      title: widget.existing == null ? 'Nouvelle enzyme' : 'Éditer l\'enzyme',
      onSave: _save,
      onDelete: widget.existing == null ? null : _delete,
      isArchived: _isArchived,
      onArchiveToggle: (v) => setState(() => _isArchived = v),
      children: [
        _Field(controller: _customCodeCtrl, label: 'Code custom (optionnel)'),
        _Field(controller: _abbrCtrl, label: 'Abréviation jargon *', hint: 'AChE, BChE, COX-2…'),
        _Field(controller: _nameCtrl, label: 'Nom complet *', hint: 'Acétylcholinestérase'),
        _Field(controller: _ecCtrl, label: 'Numéro EC', hint: '3.1.1.7'),
        _Field(controller: _chemblCtrl, label: 'ChEMBL ID', hint: 'CHEMBL220'),
        _Field(controller: _testsCtrl, label: 'Tests applicables (CSV)',
            hint: 'ANTIDIAB, ANTIINF'),
        _Field(controller: _notesCtrl, label: 'Notes', maxLines: 3),
      ],
    );
  }
}

// --- Helpers --------------------------------------------------------------

class _EditSheetScaffold extends StatelessWidget {
  const _EditSheetScaffold({
    required this.title,
    required this.children,
    required this.onSave,
    required this.isArchived,
    required this.onArchiveToggle,
    this.onDelete,
  });

  final String title;
  final List<Widget> children;
  final Future<void> Function() onSave;
  final Future<void> Function()? onDelete;
  final bool isArchived;
  final ValueChanged<bool> onArchiveToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...children,
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Archivée (masquée des listes actives)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              value: isArchived,
              onChanged: onArchiveToggle,
              activeColor: AppColors.warning,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (onDelete != null) ...[
                  TextButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Supprimer définitivement ?'),
                          content: const Text(
                              'Cette entrée sera supprimée de la base. Préfère « Archiver » pour conserver l\'historique.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Annuler')),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Supprimer'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await onDelete!();
                      }
                    },
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    child: const Text('Supprimer'),
                  ),
                  const Spacer(),
                ] else
                  const Spacer(),
                ElevatedButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Enregistrer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.italic = false,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final bool italic;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        style: TextStyle(
          fontSize: 15,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}
