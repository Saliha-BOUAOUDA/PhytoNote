import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../config/catalog.dart';
import '../data/calibration_repository.dart';
import '../data/catalog_cache.dart';
import '../data/models.dart';
import '../theme.dart';
import 'calibration_entry_screen.dart';

class NewCalibrationScreen extends StatefulWidget {
  const NewCalibrationScreen({super.key});

  @override
  State<NewCalibrationScreen> createState() => _NewCalibrationScreenState();
}

class _NewCalibrationScreenState extends State<NewCalibrationScreen> {
  final _repo = CalibrationRepository();
  final _batchCtrl = TextEditingController();
  final _controlDoCtrl = TextEditingController();

  String? _testCode;
  String? _standardCode;
  DateTime? _dateOpened;
  double? _controlDO;
  int _replicates = kDefaultCalibrationReplicates;
  int _numDilutions = kDefaultCalibrationDilutions;
  bool _saving = false;

  TestDefinition? get _test =>
      _testCode == null ? null : findTestByCode(_testCode!);

  bool get _showStandardStep =>
      _test != null && _test!.compatibleStandardAbbreviations.length > 1;

  bool get _showControlStep =>
      _test != null && _test!.needsControlDO;

  bool get _canStart {
    if (_test == null) return false;
    if (_standardCode == null) return false;
    if (_dateOpened == null) return false;
    if (_showControlStep && _controlDO == null) return false;
    return true;
  }

  void _onTestSelected(String code) {
    final test = findTestByCode(code);
    setState(() {
      _testCode = code;
      _standardCode = test?.defaultStandardAbbreviation;
      _replicates = kDefaultCalibrationReplicates;
      _numDilutions = kDefaultCalibrationDilutions;
      if (test?.needsControlDO == true) {
        final defaultCtrl = test!.defaultControlDO;
        if (defaultCtrl != null) {
          _controlDO = defaultCtrl;
          _controlDoCtrl.text = defaultCtrl.toStringAsFixed(3);
        }
      } else {
        _controlDO = null;
        _controlDoCtrl.clear();
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOpened ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOpened = picked);
  }

  Future<void> _start() async {
    if (!_canStart || _saving) return;
    setState(() => _saving = true);

    final test = _test!;
    final standard = CatalogCache.findStandardByAbbr(_standardCode!);
    final batch = _batchCtrl.text.trim();
    final dateFormatter = DateFormat('yyyy-MM-dd');
    final name = '${test.code} ${standard?.name ?? _standardCode} ${dateFormatter.format(_dateOpened!)}';
    final concentrations = generateCalibrationConcentrations(test, _numDilutions);

    final calibration = Calibration(
      id: const Uuid().v4(),
      name: name,
      testType: test.code,
      standardId: standard?.id,
      standardCodeSnapshot: standard?.abbreviation ?? _standardCode,
      standardCompound: standard?.abbreviation ?? _standardCode!,
      reagentBatchNumber: batch.isEmpty ? null : batch,
      dateCreated: DateTime.now(),
      dateOpenedFlask: _dateOpened!,
      replicates: _replicates,
      concentrations: concentrations,
      controlDO: _controlDO,
    );

    try {
      await _repo.insert(calibration);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CalibrationEntryScreen(calibrationId: calibration.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  @override
  void dispose() {
    _batchCtrl.dispose();
    _controlDoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calTests = testsCatalog.where((t) => t.supportsCalibration).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle calibration'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _StepLabel(number: 1, title: 'Test'),
                    const SizedBox(height: 10),
                    _ChipList(
                      items: calTests
                          .map((t) => _ChipData(t.code, t.name, t.shortDescription))
                          .toList(),
                      selected: _testCode,
                      onSelected: _onTestSelected,
                      columns: 2,
                    ),
                    const SizedBox(height: 22),
                    if (_showStandardStep) ...[
                      const _StepLabel(number: 2, title: 'Standard'),
                      const SizedBox(height: 10),
                      _ChipList(
                        items: _test!.compatibleStandardAbbreviations.map((abbr) {
                          final s = CatalogCache.findStandardByAbbr(abbr);
                          return _ChipData(abbr, s?.abbreviation ?? abbr, s?.equivalentLabel ?? '${abbr}eq');
                        }).toList(),
                        selected: _standardCode,
                        onSelected: (c) => setState(() => _standardCode = c),
                        columns: 2,
                      ),
                      const SizedBox(height: 22),
                    ],
                    _StepLabel(number: _showStandardStep ? 3 : 2, title: 'Lot de réactif'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _batchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'N° lot (Sigma 12345-A, optionnel)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date d\'ouverture du flacon',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today_rounded),
                        ),
                        child: Text(
                          _dateOpened == null
                              ? 'Choisir une date'
                              : DateFormat('d MMMM yyyy', 'fr_FR').format(_dateOpened!),
                          style: TextStyle(
                            fontSize: 16,
                            color: _dateOpened == null ? AppColors.textMuted : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    if (_test != null) ...[
                      const SizedBox(height: 22),
                      _StepLabel(number: _showStandardStep ? 4 : 3, title: 'Plan d\'acquisition'),
                      const SizedBox(height: 6),
                      const Text(
                        'Réplicats par concentration',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      _ChipList(
                        items: const [
                          _ChipData('2', '2', null),
                          _ChipData('3', '3', null),
                          _ChipData('4', '4', null),
                        ],
                        selected: _replicates.toString(),
                        onSelected: (v) => setState(() => _replicates = int.parse(v)),
                        columns: 3,
                      ),
                      if (isDilutionCountConfigurable(_test!)) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Nombre de dilutions /2',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        _ChipList(
                          items: const [
                            _ChipData('6', '6', null),
                            _ChipData('8', '8', null),
                            _ChipData('10', '10', null),
                          ],
                          selected: _numDilutions.toString(),
                          onSelected: (v) => setState(() => _numDilutions = int.parse(v)),
                          columns: 3,
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        Text(
                          'Plan fixe : ${generateCalibrationConcentrations(_test!, 0).length} concentrations imposées par le protocole',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                    if (_showControlStep) ...[
                      const SizedBox(height: 22),
                      _StepLabel(number: _showStandardStep ? 5 : 4, title: 'DO contrôle (référence)'),
                      const SizedBox(height: 6),
                      Text(
                        '${_test!.code} + solvant — modifiable selon ton lot',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _controlDoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        onChanged: (raw) {
                          final v = double.tryParse(raw.replaceAll(',', '.'));
                          setState(() => _controlDO = v);
                        },
                        decoration: const InputDecoration(
                          labelText: 'DO contrôle',
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ),
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
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.number, required this.title});
  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppColors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

class _ChipData {
  final String value;
  final String label;
  final String? subtitle;
  const _ChipData(this.value, this.label, [this.subtitle]);
}

class _ChipList extends StatelessWidget {
  const _ChipList({
    required this.items,
    required this.selected,
    required this.onSelected,
    required this.columns,
  });

  final List<_ChipData> items;
  final String? selected;
  final ValueChanged<String> onSelected;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final tileWidth = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items.map((item) {
            final isSelected = item.value == selected;
            final bg = isSelected ? AppColors.primary : AppColors.surfaceElevated;
            final fg = isSelected ? Colors.white : AppColors.textPrimary;
            return SizedBox(
              width: tileWidth,
              child: Material(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => onSelected(item.value),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 64),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.outline,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label,
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: fg)),
                        if (item.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? Colors.white.withOpacity(0.85)
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StartBar extends StatelessWidget {
  const _StartBar({required this.enabled, required this.isLoading, required this.onPressed});

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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Saisir les points', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 22),
                  ],
                ),
        ),
      ),
    );
  }
}
