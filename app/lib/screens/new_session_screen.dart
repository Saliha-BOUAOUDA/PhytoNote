import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../config/catalog.dart';
import '../data/catalog_cache.dart';
import '../data/catalog_models.dart';
import '../data/calibration_repository.dart';
import '../data/models.dart';
import '../data/session_repository.dart';
import '../theme.dart';
import '../widgets/scientific_label.dart';
import 'antibac_session_screen.dart';
import 'session_screen.dart';

class NewSessionScreen extends StatefulWidget {
  const NewSessionScreen({super.key, SessionRepository? repository})
      : _repo = repository;

  final SessionRepository? _repo;

  @override
  State<NewSessionScreen> createState() => _NewSessionScreenState();
}

class _NewSessionScreenState extends State<NewSessionScreen> {
  String? _testCode;
  int? _plantId;
  int? _extractId;
  int? _replicates;
  int? _standardId;
  int? _bacteriaId;
  double? _controlDOReference;
  bool _saving = false;

  TestDefinition? get _test =>
      _testCode == null ? null : findTestByCode(_testCode!);

  bool get _showStandardStep =>
      _test != null && _test!.compatibleStandardAbbreviations.length > 1;

  bool get _showBacteriaStep =>
      _test != null && _test!.requiresBacteriaStrain;

  bool get _showControlStep =>
      _test != null && _test!.defaultControlDO != null;

  bool get _canStart {
    if (_test == null) return false;
    if (_plantId == null || _extractId == null) return false;
    if (_replicates == null) return false;
    if (_standardId == null) return false;
    if (_showBacteriaStep && _bacteriaId == null) return false;
    if (_showControlStep && _controlDOReference == null) return false;
    return true;
  }

  void _onTestSelected(String code) {
    final test = findTestByCode(code);
    setState(() {
      _testCode = code;
      _replicates = test?.defaultReplicates;
      _controlDOReference = test?.defaultControlDO;
      _standardId = null;
      _bacteriaId = null;
      // Si un seul standard compatible : auto-select via cache
      if (test != null) {
        if (test.compatibleStandardAbbreviations.length == 1) {
          final std = CatalogCache.findStandardByAbbr(
              test.compatibleStandardAbbreviations.first);
          _standardId = std?.id;
        } else {
          // Pré-sélection du premier compatible disponible
          final firstAbbr = test.defaultStandardAbbreviation;
          final std = CatalogCache.findStandardByAbbr(firstAbbr);
          _standardId = std?.id;
        }
      }
    });
  }

  Future<void> _start() async {
    if (!_canStart || _saving) return;
    setState(() => _saving = true);

    final plant = CatalogCache.findPlant(_plantId);
    final extract = CatalogCache.findExtract(_extractId);
    final standard = CatalogCache.findStandard(_standardId);
    final bacteria = CatalogCache.findBacteria(_bacteriaId);
    final test = _test!;

    String? linkedCalibrationId;
    if (test.supportsCalibration && standard != null) {
      final calRepo = CalibrationRepository();
      final cal = await calRepo.latestValidFor(
        testType: test.code,
        standardCode: standard.abbreviation,
      );
      linkedCalibrationId = cal?.id;
    }

    final session = Session(
      id: const Uuid().v4(),
      startedAt: DateTime.now(),
      status: SessionStatus.active,
      plantId: plant?.id,
      plantCodeSnapshot: plant?.displayCode,
      plantNameSnapshot: plant?.fullName,
      extractId: extract?.id,
      extractAbbrSnapshot: extract?.abbreviation,
      extractNameSnapshot: extract?.name,
      testType: _testCode!,
      calibrationId: linkedCalibrationId,
      replicates: _replicates!,
      standardId: standard?.id,
      standardCodeSnapshot: standard?.abbreviation,
      controlDOReference: _controlDOReference,
      bacteriaId: bacteria?.id,
      bacteriaCodeSnapshot: bacteria?.abbreviation,
    );

    try {
      final repo = widget._repo ?? SessionRepository();
      await repo.insert(session);
      if (!mounted) return;
      if (linkedCalibrationId == null && test.supportsCalibration) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠ Aucune calibration valide trouvée — équivalents non calculés'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => test.requiresPlateView
              ? AntibacSessionScreen(sessionId: session.id)
              : SessionScreen(sessionId: session.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle manip'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Annuler',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildSteps()),
            _StartBar(
              enabled: _canStart && !_saving,
              isLoading: _saving,
              onPressed: _start,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSteps() {
    int stepIndex = 0;
    final steps = <Widget>[];

    steps.add(_Step(
      number: ++stepIndex,
      title: 'Test',
      isActive: true,
      isComplete: _testCode != null,
      child: _ChipGrid(
        items: testsCatalog
            .map((t) => _ChipItem<String>(
                  value: t.code,
                  label: t.name,
                  subtitle: t.shortDescription,
                ))
            .toList(),
        selected: _testCode,
        onSelected: _onTestSelected,
        columns: 2,
      ),
    ));

    final plants = CatalogCache.activePlants();
    steps.add(_Step(
      number: ++stepIndex,
      title: 'Plante',
      subtitle: plants.isEmpty ? 'Aucune plante au catalogue — ajoute-en depuis l\'écran Catalogue' : null,
      isActive: _testCode != null,
      isComplete: _plantId != null,
      child: plants.isEmpty
          ? const _EmptyCatalogHint(message: 'Catalogue vide pour les plantes')
          : _ChipGrid(
              items: plants
                  .map((p) => _ChipItem<int>(
                        value: p.id!,
                        label: p.displayCode,
                        subtitle: p.name,
                      ))
                  .toList(),
              selected: _plantId,
              onSelected: (id) => setState(() => _plantId = id),
              columns: 3,
              disabled: _testCode == null,
            ),
    ));

    final extracts = CatalogCache.activeExtracts();
    steps.add(_Step(
      number: ++stepIndex,
      title: 'Type d\'extrait',
      subtitle: extracts.isEmpty ? 'Aucun extrait au catalogue — importe un Starter Pack ou ajoute-en' : null,
      isActive: _plantId != null,
      isComplete: _extractId != null,
      child: extracts.isEmpty
          ? const _EmptyCatalogHint(message: 'Catalogue vide pour les extraits')
          : _ChipGrid(
              items: extracts
                  .map((e) => _ChipItem<int>(
                        value: e.id!,
                        label: e.abbreviation,
                        subtitle: e.name,
                      ))
                  .toList(),
              selected: _extractId,
              onSelected: (id) => setState(() => _extractId = id),
              columns: 2,
              disabled: _plantId == null,
            ),
    ));

    steps.add(_Step(
      number: ++stepIndex,
      title: 'Réplicats',
      subtitle: 'Nombre de réplicats par concentration',
      isActive: _extractId != null,
      isComplete: _replicates != null,
      child: _ChipGrid(
        items: const [
          _ChipItem<int>(value: 2, label: '2', subtitle: null),
          _ChipItem<int>(value: 3, label: '3', subtitle: null),
          _ChipItem<int>(value: 4, label: '4', subtitle: null),
        ],
        selected: _replicates,
        onSelected: (v) => setState(() => _replicates = v),
        columns: 3,
        disabled: _extractId == null,
      ),
    ));

    if (_showStandardStep) {
      final test = _test!;
      final compatible = test.compatibleStandardAbbreviations
          .map(CatalogCache.findStandardByAbbr)
          .whereType<Standard>()
          .toList();
      steps.add(_Step(
        number: ++stepIndex,
        title: 'Standard de référence',
        subtitle: compatible.isEmpty
            ? 'Aucun standard compatible au catalogue'
            : 'Pour la calibration et l\'expression des résultats',
        isActive: _replicates != null,
        isComplete: _standardId != null,
        child: compatible.isEmpty
            ? const _EmptyCatalogHint(message: 'Aucun standard compatible — importe un Starter Pack')
            : _ChipGrid(
                items: compatible
                    .map((s) => _ChipItem<int>(
                          value: s.id!,
                          label: s.abbreviation,
                          subtitle: s.equivalentLabel,
                        ))
                    .toList(),
                selected: _standardId,
                onSelected: (id) => setState(() => _standardId = id),
                columns: 2,
                disabled: _replicates == null,
              ),
      ));
    }

    if (_showBacteriaStep) {
      final bacteria = CatalogCache.activeBacteria();
      steps.add(_Step(
        number: ++stepIndex,
        title: 'Souche bactérienne',
        subtitle: bacteria.isEmpty
            ? 'Aucune bactérie au catalogue'
            : 'À tester contre l\'échantillon',
        isActive: _replicates != null && _standardId != null,
        isComplete: _bacteriaId != null,
        child: bacteria.isEmpty
            ? const _EmptyCatalogHint(message: 'Catalogue vide — importe un Starter Pack Antibactérien')
            : _ChipGrid(
                items: bacteria
                    .map((b) => _ChipItem<int>(
                          value: b.id!,
                          label: b.abbreviation,
                          subtitle: '${b.name} · Gram ${b.gram}',
                          italicLabel: true,
                        ))
                    .toList(),
                selected: _bacteriaId,
                onSelected: (id) => setState(() => _bacteriaId = id),
                columns: 1,
                disabled: !(_replicates != null && _standardId != null),
              ),
      ));
    }

    if (_showControlStep) {
      steps.add(_Step(
        number: ++stepIndex,
        title: 'Contrôle attendu',
        subtitle: 'DO du contrôle (${_test!.code} + solvant) — modifiable selon ton lot',
        isActive: _replicates != null && _standardId != null,
        isComplete: _controlDOReference != null,
        child: _ControlReferenceField(
          initial: _controlDOReference ?? _test!.defaultControlDO!,
          enabled: _replicates != null && _standardId != null,
          onChanged: (v) => setState(() => _controlDOReference = v),
        ),
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            steps[i],
            if (i < steps.length - 1) const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    this.subtitle,
    required this.isActive,
    required this.isComplete,
    required this.child,
  });

  final int number;
  final String title;
  final String? subtitle;
  final bool isActive;
  final bool isComplete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final headerColor = !isActive
        ? AppColors.textMuted
        : isComplete
            ? AppColors.primary
            : AppColors.textPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: isComplete
                    ? AppColors.primary
                    : isActive
                        ? AppColors.primaryContainer
                        : AppColors.outline,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isComplete
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                    : Text(
                        '$number',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isActive ? AppColors.primaryDark : AppColors.textMuted,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: headerColor),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isActive ? AppColors.textSecondary : AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Opacity(
          opacity: isActive ? 1 : 0.5,
          child: child,
        ),
      ],
    );
  }
}

class _ChipItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final bool italicLabel;
  const _ChipItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.italicLabel = false,
  });
}

class _ChipGrid<T> extends StatelessWidget {
  const _ChipGrid({
    required this.items,
    required this.selected,
    required this.onSelected,
    required this.columns,
    this.disabled = false,
  });

  final List<_ChipItem<T>> items;
  final T? selected;
  final ValueChanged<T> onSelected;
  final int columns;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final tileWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items.map((item) {
            final isSelected = item.value == selected;
            return SizedBox(
              width: tileWidth,
              child: _SelectableTile(
                label: item.label,
                subtitle: item.subtitle,
                italicLabel: item.italicLabel,
                isSelected: isSelected,
                onTap: disabled ? null : () => onSelected(item.value),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
    required this.label,
    this.subtitle,
    required this.isSelected,
    this.onTap,
    this.italicLabel = false,
  });

  final String label;
  final String? subtitle;
  final bool isSelected;
  final bool italicLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isSelected ? AppColors.primary : AppColors.surfaceElevated;
    final fg = isSelected ? Colors.white : AppColors.textPrimary;
    final borderColor = isSelected ? AppColors.primary : AppColors.outline;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScientificLabel(
                text: label,
                italic: italicLabel,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? Colors.white.withOpacity(0.85)
                        : AppColors.textSecondary,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCatalogHint extends StatelessWidget {
  const _EmptyCatalogHint({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary, height: 1.3)),
          ),
        ],
      ),
    );
  }
}

class _ControlReferenceField extends StatefulWidget {
  const _ControlReferenceField({
    required this.initial,
    required this.enabled,
    required this.onChanged,
  });

  final double initial;
  final bool enabled;
  final ValueChanged<double?> onChanged;

  @override
  State<_ControlReferenceField> createState() => _ControlReferenceFieldState();
}

class _ControlReferenceFieldState extends State<_ControlReferenceField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial.toStringAsFixed(3));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onChanged(widget.initial);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    final cleaned = raw.trim().replaceAll(',', '.');
    final v = double.tryParse(cleaned);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      enabled: widget.enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      onChanged: _onChanged,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      decoration: const InputDecoration(
        labelText: 'DO contrôle attendu',
        hintText: 'ex. 1.300',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
    );
  }
}

class _StartBar extends StatelessWidget {
  const _StartBar({
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
  });

  final bool enabled;
  final bool isLoading;
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Démarrer la manip',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 22),
                  ],
                ),
        ),
      ),
    );
  }
}
