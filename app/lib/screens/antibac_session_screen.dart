import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/catalog.dart';
import '../data/catalog_cache.dart';
import '../data/catalog_models.dart';
import '../data/measurement_repository.dart';
import '../data/models.dart';
import '../data/session_repository.dart';
import '../services/antibac_helpers.dart';
import '../services/excel_export.dart';
import '../services/validation.dart';
import '../theme.dart';
import '../widgets/export_snackbar.dart';
import '../widgets/keyboard_nav_bar.dart';
import '../widgets/results_banner.dart';
import '../widgets/scientific_label.dart';

class AntibacSessionScreen extends StatefulWidget {
  const AntibacSessionScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<AntibacSessionScreen> createState() => _AntibacSessionScreenState();
}

class _AntibacSessionScreenState extends State<AntibacSessionScreen> {
  final _sessionRepo = SessionRepository();
  final _measurementRepo = MeasurementRepository();

  Session? _session;
  TestDefinition? _test;
  Plant? _plant;
  Extract? _extract;
  Standard? _standard;
  Bacteria? _bacteria;
  List<double> _sampleConcentrations = const [];
  List<double> _standardConcentrations = const [];
  Map<String, Measurement> _byKey = {};
  final _cmbCtrl = TextEditingController();
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cmbCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final session = await _sessionRepo.byId(widget.sessionId);
      if (session == null) {
        setState(() {
          _loading = false;
          _loadError = 'Session introuvable';
        });
        return;
      }
      final test = findTestByCode(session.testType);
      if (test == null || !test.requiresPlateView) {
        setState(() {
          _loading = false;
          _loadError = 'Test incompatible avec la vue plaque';
        });
        return;
      }
      final plant = CatalogCache.findPlant(session.plantId);
      final extract = CatalogCache.findExtract(session.extractId);
      final standard = CatalogCache.findStandard(session.standardId);
      final bacteria = CatalogCache.findBacteria(session.bacteriaId);
      final existing = await _measurementRepo.bySession(session.id);
      setState(() {
        _session = session;
        _test = test;
        _plant = plant;
        _extract = extract;
        _standard = standard;
        _bacteria = bacteria;
        _sampleConcentrations = defaultConcentrationsFor(
            test, extract?.isHighConcentrationSample ?? false);
        _standardConcentrations = standardAntibioticConcentrations();
        _byKey = {for (final m in existing) _key(m.wellRole, m.concentration, m.replicateNumber): m};
        if (session.cmbUgPerMl != null) {
          _cmbCtrl.text = session.cmbUgPerMl!.toStringAsFixed(3);
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _loadError = 'Erreur de chargement : $e';
      });
    }
  }

  String _key(String role, double conc, int rep) =>
      '$role|${conc.toStringAsFixed(6)}|$rep';

  Future<void> _saveWell({
    required String wellRole,
    required double concentration,
    required int replicate,
    required double rawDO,
    String? observedColor,
  }) async {
    final session = _session!;
    final m = Measurement(
      id: MeasurementRepository.idFor(session.id, concentration, replicate, wellRole: wellRole),
      sessionId: session.id,
      concentration: concentration,
      replicateNumber: replicate,
      rawDO: rawDO,
      measuredAt: DateTime.now(),
      wellRole: wellRole,
      observedColor: observedColor,
      validationStatus: validateDO(rawDO).level.name,
    );
    await _measurementRepo.upsert(m);
    setState(() {
      _byKey[_key(wellRole, concentration, replicate)] = m;
    });
  }

  Future<void> _saveCMB() async {
    final raw = _cmbCtrl.text.trim().replaceAll(',', '.');
    final v = double.tryParse(raw);
    if (v == null) return;
    final session = _session!.copyWith(cmbUgPerMl: v);
    await _sessionRepo.update(session);
    setState(() => _session = session);
  }

  Future<void> _exportAndShare() async {
    try {
      final session = _session;
      final test = _test;
      if (session == null || test == null) return;
      final file = await exportAntibacSessionToExcel(
        session: session,
        test: test,
        plant: _plant,
        bacteria: _bacteria,
        standard: _standard,
        measurements: _allMeasurements,
        sampleConcentrations: _sampleConcentrations,
        standardConcentrations: _standardConcentrations,
        cmiSample: _computedCMI,
        cmiStandard: _standardCMI,
        controlIssues: _controlIssues,
      );
      if (!mounted) return;
      showExportSuccessSnackBar(context, file);
    } catch (e) {
      if (!mounted) return;
      showExportErrorSnackBar(context, e);
    }
  }

  Future<void> _complete() async {
    final cmi = _computedCMI;
    if (cmi != null) {
      final updated = _session!.copyWith(cmiUgPerMl: cmi);
      await _sessionRepo.update(updated);
    }
    await _sessionRepo.markCompleted(_session!.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  List<Measurement> get _allMeasurements => _byKey.values.toList();

  double? get _computedCMI {
    final sorted = [..._sampleConcentrations]..sort((a, b) => b.compareTo(a));
    return computeCMI(
      measurements: _allMeasurements,
      sortedConcentrationsDescending: sorted,
      wellRole: WellRole.sample,
    );
  }

  double? get _standardCMI {
    final sorted = [..._standardConcentrations]..sort((a, b) => b.compareTo(a));
    return computeCMI(
      measurements: _allMeasurements,
      sortedConcentrationsDescending: sorted,
      wellRole: WellRole.standard,
    );
  }

  List<String> get _controlIssues {
    final controls = _allMeasurements.where((m) =>
        m.wellRole == WellRole.controlGrowth ||
        m.wellRole == WellRole.controlSterility ||
        m.wellRole == WellRole.controlHE).toList();
    return validateAntibacControls(controls);
  }

  bool get _canComplete {
    if (_session == null) return false;
    if (_controlIssues.isNotEmpty) return false;
    if (_computedCMI == null) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_loadError!, textAlign: TextAlign.center),
        )),
      );
    }

    final session = _session!;
    final test = _test!;
    final plantLabel = session.plantCodeSnapshot ?? '?';

    return Scaffold(
      appBar: AppBar(
        title: Text('Plaque $plantLabel · ${test.code}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: exportButtonTooltip(),
            onPressed: _exportAndShare,
          ),
        ],
      ),
      bottomNavigationBar: const KeyboardNavBar(),
      body: SafeArea(
        child: Column(
          children: [
            _buildAntibacBanner(test),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AntibacHeader(
                      session: session,
                      test: test,
                      plant: _plant,
                      extract: _extract,
                      bacteria: _bacteria,
                      standard: _standard,
                    ),
                    const SizedBox(height: 18),
                    _ControlsSection(
                      byKey: _byKey,
                      keyOf: _key,
                      issues: _controlIssues,
                      onSave: _saveWell,
                    ),
                    const SizedBox(height: 18),
                    _DilutionSection(
                      title: 'Échantillon — ${test.code} $plantLabel',
                      subtitle: 'Sérige diluée /2 dans DMSO ; couleur après résazurine',
                      wellRole: WellRole.sample,
                      concentrations: _sampleConcentrations,
                      unit: test.concentrationUnit,
                      replicates: session.replicates,
                      byKey: _byKey,
                      keyOf: _key,
                      onSave: _saveWell,
                    ),
                    const SizedBox(height: 18),
                    _DilutionSection(
                      title: 'Standard antibio — ${_standard?.name ?? "?"}',
                      subtitle: 'Plage CLSI 64 → 0.06 µg/mL · validation interne',
                      wellRole: WellRole.standard,
                      concentrations: _standardConcentrations,
                      unit: 'µg/mL',
                      replicates: session.replicates,
                      byKey: _byKey,
                      keyOf: _key,
                      onSave: _saveWell,
                    ),
                    const SizedBox(height: 18),
                    _ResultsSection(
                      cmiUgPerMl: _computedCMI,
                      cmiUnit: test.concentrationUnit,
                      standardCMI: _standardCMI,
                      standardAbbr: _standard?.abbreviation,
                      bacteriaAbbr: _bacteria?.abbreviation,
                      cmbCtrl: _cmbCtrl,
                      onSaveCMB: _saveCMB,
                    ),
                  ],
                ),
              ),
            ),
            _CompleteBar(
              enabled: _canComplete,
              issues: _controlIssues,
              onPressed: _complete,
            ),
          ],
        ),
      ),
    );
  }
}

extension _AntibacBanner on _AntibacSessionScreenState {
  Widget _buildAntibacBanner(TestDefinition test) {
    final cmi = _computedCMI;
    final issues = _controlIssues;
    final filled = _byKey.values.where((m) => m.wellRole == WellRole.sample).length;
    final expected = _sampleConcentrations.length * (_session?.replicates ?? 2);

    Color statusColor;
    IconData statusIcon;
    if (issues.isNotEmpty) {
      statusColor = AppColors.danger;
      statusIcon = Icons.error_outline_rounded;
    } else if (cmi != null) {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle_rounded;
    } else if (filled > 0) {
      statusColor = AppColors.warning;
      statusIcon = Icons.timelapse_rounded;
    } else {
      statusColor = AppColors.textMuted;
      statusIcon = Icons.timelapse_rounded;
    }

    final stats = <BannerStat>[
      if (cmi != null)
        BannerStat(
          label: 'CMI',
          value: '${cmi.toStringAsFixed(3)} ${test.concentrationUnit}',
          color: statusColor,
        ),
      BannerStat(
        label: 'puits',
        value: '$filled/$expected',
      ),
      BannerStat(
        label: 'contrôles',
        value: issues.isEmpty ? '✓' : '⚠',
        color: issues.isEmpty ? AppColors.success : AppColors.danger,
      ),
    ];

    return ResultsBanner(
      stats: stats,
      statusColor: statusColor,
      statusIcon: statusIcon,
      message: filled == 0 ? 'Saisis les contrôles + ≥ 1 puits pour démarrer' : null,
    );
  }
}

class _AntibacHeader extends StatelessWidget {
  const _AntibacHeader({
    required this.session,
    required this.test,
    required this.plant,
    required this.extract,
    required this.bacteria,
    required this.standard,
  });

  final Session session;
  final TestDefinition test;
  final Plant? plant;
  final Extract? extract;
  final Bacteria? bacteria;
  final Standard? standard;

  @override
  Widget build(BuildContext context) {
    final plantLabel = session.plantCodeSnapshot ?? '?';
    final extractLabel = session.extractAbbrSnapshot ?? '?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Pill(label: test.code, isPrimary: true),
              _Pill(label: plantLabel, isPrimary: true),
              _Pill(label: extractLabel),
              if (bacteria != null) _Pill(label: bacteria!.abbreviation, italic: true),
              if (standard != null) _Pill(label: standard!.name),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Microdilution MIC/MBC · résazurine · 24 h à 37°C',
            style: TextStyle(fontSize: 13, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
          ),
          if (bacteria != null) ...[
            const SizedBox(height: 2),
            Text(
              '${bacteria!.name} · Gram ${bacteria!.gram} · ${bacteria!.atccSuggested ?? "ATCC ?"}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.isPrimary = false, this.italic = false});
  final String label;
  final bool isPrimary;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary, width: 1),
      ),
      child: ScientificLabel(
        text: label,
        italic: italic,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isPrimary ? Colors.white : AppColors.primaryDark,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _ControlsSection extends StatelessWidget {
  const _ControlsSection({
    required this.byKey,
    required this.keyOf,
    required this.issues,
    required this.onSave,
  });

  final Map<String, Measurement> byKey;
  final String Function(String, double, int) keyOf;
  final List<String> issues;
  final Future<void> Function({
    required String wellRole,
    required double concentration,
    required int replicate,
    required double rawDO,
    String? observedColor,
  }) onSave;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Contrôles obligatoires',
      subtitle: 'Validation de la manip — saisir DO + couleur après résazurine',
      footerWidget: issues.isEmpty
          ? const Text('Tous les contrôles conformes', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: issues
                  .map((i) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('⚠ $i', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w500, fontSize: 13)),
                      ))
                  .toList(),
            ),
      child: Column(
        children: [
          _ControlRow(
            label: 'T+ croissance',
            hint: 'Milieu + bactérie. Attendu : rose / turbide',
            wellRole: WellRole.controlGrowth,
            existing: byKey[keyOf(WellRole.controlGrowth, 0, 1)],
            onSave: onSave,
          ),
          const Divider(height: 24, color: AppColors.outline),
          _ControlRow(
            label: 'T− stérilité',
            hint: 'Milieu seul. Attendu : mauve / limpide',
            wellRole: WellRole.controlSterility,
            existing: byKey[keyOf(WellRole.controlSterility, 0, 1)],
            onSave: onSave,
          ),
          const Divider(height: 24, color: AppColors.outline),
          _ControlRow(
            label: 'T− HE seule',
            hint: 'HE 250 µl/mL + milieu sans bactérie. Attendu : mauve',
            wellRole: WellRole.controlHE,
            existing: byKey[keyOf(WellRole.controlHE, 0, 1)],
            onSave: onSave,
          ),
        ],
      ),
    );
  }
}

class _ControlRow extends StatefulWidget {
  const _ControlRow({
    required this.label,
    required this.hint,
    required this.wellRole,
    required this.existing,
    required this.onSave,
  });

  final String label;
  final String hint;
  final String wellRole;
  final Measurement? existing;
  final Future<void> Function({
    required String wellRole,
    required double concentration,
    required int replicate,
    required double rawDO,
    String? observedColor,
  }) onSave;

  @override
  State<_ControlRow> createState() => _ControlRowState();
}

class _ControlRowState extends State<_ControlRow> {
  late final TextEditingController _doCtrl;
  String? _color;
  double? _do;

  @override
  void initState() {
    super.initState();
    _doCtrl = TextEditingController(text: widget.existing?.rawDO.toStringAsFixed(3) ?? '');
    _do = widget.existing?.rawDO;
    _color = widget.existing?.observedColor;
  }

  @override
  void dispose() {
    _doCtrl.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    if (_do == null) return;
    await widget.onSave(
      wellRole: widget.wellRole,
      concentration: 0,
      replicate: 1,
      rawDO: _do!,
      observedColor: _color,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
        const SizedBox(height: 2),
        Text(widget.hint, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _doCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                textInputAction: TextInputAction.next,
                onChanged: (raw) {
                  final v = parseDecimal(raw);
                  setState(() => _do = v);
                  if (v != null) _persist();
                },
                onEditingComplete: _persist,
                onSubmitted: (_) => _persist(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  labelText: 'DO 600 nm',
                  helperText: 'Virgule ou point · sauvegarde auto',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _ColorToggle(
              color: _color,
              onChanged: (c) {
                setState(() => _color = c);
                _persist();
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _ColorToggle extends StatelessWidget {
  const _ColorToggle({required this.color, required this.onChanged});

  final String? color;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ColorChip(
            label: 'Mauve',
            value: ObservedColor.mauve,
            color: const Color(0xFF7C3AED),
            isSelected: color == ObservedColor.mauve,
            onTap: () => onChanged(color == ObservedColor.mauve ? null : ObservedColor.mauve),
          ),
          Container(width: 1, height: 32, color: AppColors.outline),
          _ColorChip(
            label: 'Rose',
            value: ObservedColor.pink,
            color: const Color(0xFFEC4899),
            isSelected: color == ObservedColor.pink,
            onTap: () => onChanged(color == ObservedColor.pink ? null : ObservedColor.pink),
          ),
        ],
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.label,
    required this.value,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.18) : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected ? Border.all(color: color, width: 2) : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DilutionSection extends StatelessWidget {
  const _DilutionSection({
    required this.title,
    required this.subtitle,
    required this.wellRole,
    required this.concentrations,
    required this.unit,
    required this.replicates,
    required this.byKey,
    required this.keyOf,
    required this.onSave,
  });

  final String title;
  final String subtitle;
  final String wellRole;
  final List<double> concentrations;
  final String unit;
  final int replicates;
  final Map<String, Measurement> byKey;
  final String Function(String, double, int) keyOf;
  final Future<void> Function({
    required String wellRole,
    required double concentration,
    required int replicate,
    required double rawDO,
    String? observedColor,
  }) onSave;

  int get _filled => byKey.values.where((m) => m.wellRole == wellRole).length;
  int get _expected => concentrations.length * replicates;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      subtitle: '$subtitle · $_filled / $_expected saisies',
      child: Column(
        children: [
          for (var i = 0; i < concentrations.length; i++) ...[
            _ConcentrationRow(
              concentration: concentrations[i],
              unit: unit,
              wellRole: wellRole,
              replicates: replicates,
              byKey: byKey,
              keyOf: keyOf,
              onSave: onSave,
            ),
            if (i < concentrations.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: AppColors.outline),
              ),
          ],
        ],
      ),
    );
  }
}

class _ConcentrationRow extends StatelessWidget {
  const _ConcentrationRow({
    required this.concentration,
    required this.unit,
    required this.wellRole,
    required this.replicates,
    required this.byKey,
    required this.keyOf,
    required this.onSave,
  });

  final double concentration;
  final String unit;
  final String wellRole;
  final int replicates;
  final Map<String, Measurement> byKey;
  final String Function(String, double, int) keyOf;
  final Future<void> Function({
    required String wellRole,
    required double concentration,
    required int replicate,
    required double rawDO,
    String? observedColor,
  }) onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(formatConcentration(concentration, unit), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
        const SizedBox(height: 6),
        for (var rep = 1; rep <= replicates; rep++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _WellRow(
              label: 'R$rep',
              wellRole: wellRole,
              concentration: concentration,
              replicate: rep,
              existing: byKey[keyOf(wellRole, concentration, rep)],
              onSave: onSave,
            ),
          ),
      ],
    );
  }
}

class _WellRow extends StatefulWidget {
  const _WellRow({
    required this.label,
    required this.wellRole,
    required this.concentration,
    required this.replicate,
    required this.existing,
    required this.onSave,
  });

  final String label;
  final String wellRole;
  final double concentration;
  final int replicate;
  final Measurement? existing;
  final Future<void> Function({
    required String wellRole,
    required double concentration,
    required int replicate,
    required double rawDO,
    String? observedColor,
  }) onSave;

  @override
  State<_WellRow> createState() => _WellRowState();
}

class _WellRowState extends State<_WellRow> {
  late final TextEditingController _doCtrl;
  String? _color;
  double? _do;

  @override
  void initState() {
    super.initState();
    _doCtrl = TextEditingController(text: widget.existing?.rawDO.toStringAsFixed(3) ?? '');
    _do = widget.existing?.rawDO;
    _color = widget.existing?.observedColor;
  }

  @override
  void dispose() {
    _doCtrl.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    if (_do == null) return;
    await widget.onSave(
      wellRole: widget.wellRole,
      concentration: widget.concentration,
      replicate: widget.replicate,
      rawDO: _do!,
      observedColor: _color,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(widget.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: TextField(
            controller: _doCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            textInputAction: TextInputAction.next,
            onChanged: (raw) {
              final v = parseDecimal(raw);
              setState(() => _do = v);
              if (v != null) _persist();
            },
            onEditingComplete: _persist,
            onSubmitted: (_) => _persist(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: 'DO',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _ColorToggle(
          color: _color,
          onChanged: (c) {
            setState(() => _color = c);
            _persist();
          },
        ),
      ],
    );
  }
}

class _ResultsSection extends StatelessWidget {
  const _ResultsSection({
    required this.cmiUgPerMl,
    required this.cmiUnit,
    required this.standardCMI,
    required this.standardAbbr,
    required this.bacteriaAbbr,
    required this.cmbCtrl,
    required this.onSaveCMB,
  });

  final double? cmiUgPerMl;
  final String cmiUnit;
  final double? standardCMI;
  final String? standardAbbr;
  final String? bacteriaAbbr;
  final TextEditingController cmbCtrl;
  final Future<void> Function() onSaveCMB;

  @override
  Widget build(BuildContext context) {
    final stdRange = (standardAbbr != null && bacteriaAbbr != null)
        ? expectedStandardMICRange(
            standardAbbreviation: standardAbbr!,
            bacteriaAbbreviation: bacteriaAbbr!)
        : null;
    final stdValid = standardCMI == null || stdRange == null
        ? null
        : (standardCMI! >= stdRange.low && standardCMI! <= stdRange.high);

    return _SectionCard(
      title: 'Résultats',
      subtitle: 'CMI auto-déterminée · CMB à saisir après gélose 24 h',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ResultRow(
            label: 'CMI échantillon',
            value: cmiUgPerMl == null ? '—' : '${cmiUgPerMl!.toStringAsFixed(3)} $cmiUnit',
            hint: cmiUgPerMl == null ? 'En attente de réplicats mauves' : 'Plus petite [C] où tous les réplicats sont mauves',
          ),
          const SizedBox(height: 10),
          _ResultRow(
            label: 'CMI standard antibio',
            value: standardCMI == null ? '—' : '${standardCMI!.toStringAsFixed(3)} µg/mL',
            hint: stdRange == null
                ? 'Plage attendue inconnue pour cette combinaison'
                : 'Plage CLSI : ${stdRange.low}–${stdRange.high} µg/mL',
            valueColor: stdValid == null
                ? null
                : (stdValid ? AppColors.success : AppColors.danger),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: cmbCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(
                    labelText: 'CMB (µg/mL ou µl/mL)',
                    hintText: 'Saisir après lecture gélose 24 h',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: onSaveCMB,
                icon: const Icon(Icons.save_outlined, size: 20),
                label: const Text('Enregistrer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value, required this.hint, this.valueColor});

  final String label;
  final String value;
  final String hint;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text(hint, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.footerWidget,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footerWidget;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          child,
          if (footerWidget != null) ...[
            const SizedBox(height: 12),
            footerWidget!,
          ],
        ],
      ),
    );
  }
}

class _CompleteBar extends StatelessWidget {
  const _CompleteBar({required this.enabled, required this.issues, required this.onPressed});

  final bool enabled;
  final List<String> issues;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SizedBox(
        height: 64,
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.outline,
            disabledForegroundColor: AppColors.textMuted,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                enabled ? 'Terminer la manip' : (issues.isNotEmpty ? 'Contrôles invalides' : 'Saisir au moins une CMI'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
