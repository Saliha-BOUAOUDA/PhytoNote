import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fl_chart/fl_chart.dart';

import '../config/catalog.dart';
import '../data/catalog_cache.dart';
import '../data/catalog_models.dart';
import '../data/calibration_repository.dart';
import '../data/measurement_repository.dart';
import '../data/models.dart';
import '../data/session_repository.dart';
import '../services/excel_export.dart';
import '../services/regression.dart';
import '../services/results.dart';
import '../services/validation.dart';
import '../theme.dart';
import '../widgets/export_snackbar.dart';
import '../widgets/keyboard_nav_bar.dart';
import '../widgets/results_banner.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final _sessionRepo = SessionRepository();
  final _measurementRepo = MeasurementRepository();
  final _calibrationRepo = CalibrationRepository();
  final _scrollCtrl = ScrollController();
  final _resultsKey = GlobalKey();

  Session? _session;
  TestDefinition? _test;
  Plant? _plant;
  Extract? _extract;
  Calibration? _calibration;
  List<double> _concentrations = const [];
  Map<String, Measurement> _byKey = {};
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToResults() {
    final ctx = _resultsKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  Future<void> _exportAndShare(
    Session session,
    TestDefinition test,
    Plant? plant,
    Calibration? calibration,
    Standard? standard,
    SessionResults results,
  ) async {
    try {
      final file = await exportSessionToExcel(
        session: session,
        test: test,
        plant: plant,
        calibration: calibration,
        standard: standard,
        measurements: _byKey.values.toList(),
        results: results,
      );
      if (!mounted) return;
      showExportSuccessSnackBar(context, file);
    } catch (e) {
      if (!mounted) return;
      showExportErrorSnackBar(context, e);
    }
  }

  Future<void> _loadSession() async {
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
      final plant = CatalogCache.findPlant(session.plantId);
      final extract = CatalogCache.findExtract(session.extractId);
      if (test == null) {
        setState(() {
          _loading = false;
          _loadError = 'Test inconnu : ${session.testType}';
        });
        return;
      }
      final concs = defaultConcentrationsFor(
          test, extract?.isHighConcentrationSample ?? false);
      final existing = await _measurementRepo.bySession(session.id);
      Calibration? cal;
      if (session.calibrationId != null) {
        cal = await _calibrationRepo.byId(session.calibrationId!);
      }
      setState(() {
        _session = session;
        _test = test;
        _plant = plant;
        _extract = extract;
        _calibration = cal;
        _concentrations = concs;
        _byKey = {for (final m in existing) _planKey(m.concentration, m.replicateNumber): m};
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _loadError = 'Erreur de chargement : $e';
      });
    }
  }

  String _planKey(double conc, int rep) =>
      '${conc.toStringAsFixed(6)}|$rep';

  Future<void> _saveMeasurement({
    required double concentration,
    required int replicate,
    required double rawDO,
  }) async {
    final session = _session!;
    final m = Measurement(
      id: MeasurementRepository.idFor(session.id, concentration, replicate),
      sessionId: session.id,
      concentration: concentration,
      replicateNumber: replicate,
      rawDO: rawDO,
      measuredAt: DateTime.now(),
      validationStatus: validateDO(rawDO).level.name,
    );
    await _measurementRepo.upsert(m);
    setState(() {
      _byKey[_planKey(concentration, replicate)] = m;
    });
  }

  Future<void> _toggleExcluded(double concentration, bool excluded) async {
    final affected = _byKey.values
        .where((m) => m.concentration == concentration)
        .toList();
    for (final m in affected) {
      final updated = Measurement(
        id: m.id,
        sessionId: m.sessionId,
        concentration: m.concentration,
        replicateNumber: m.replicateNumber,
        rawDO: m.rawDO,
        measuredAt: m.measuredAt,
        wellRole: m.wellRole,
        observedColor: m.observedColor,
        validationStatus: m.validationStatus,
        validationMessage: m.validationMessage,
        isExcluded: excluded,
        exclusionReason: excluded ? 'Hors plage linéaire' : null,
      );
      await _measurementRepo.upsert(updated);
      if (!mounted) return;
      setState(() {
        _byKey[_planKey(m.concentration, m.replicateNumber)] = updated;
      });
    }
  }

  Future<void> _saveControl(double value) async {
    await _sessionRepo.setControlMeasurement(_session!.id, value);
    setState(() {
      _session = _session!.copyWith(
        controlMeasurement: value,
        controlMeasuredAt: DateTime.now(),
      );
    });
  }

  Future<void> _completeSession() async {
    await _sessionRepo.markCompleted(_session!.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  int get _expectedMeasurements =>
      _concentrations.length * (_session?.replicates ?? 2);

  int get _filledMeasurements => _byKey.length;

  double? get _expectedControlDO =>
      _session?.controlDOReference ?? _test?.defaultControlDO;

  bool get _canComplete {
    if (_session == null || _test == null) return false;
    final controlOK = _expectedControlDO == null || _session!.controlMeasurement != null;
    return controlOK && _filledMeasurements > 0;
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
    final unit = test.concentrationUnit;
    final results = computeSessionResults(
      session: session,
      test: test,
      calibration: _calibration,
      measurements: _byKey.values.toList(),
    );
    final standard = CatalogCache.findStandard(session.standardId);
    final plantLabel = session.plantCodeSnapshot ?? '?';

    return Scaffold(
      appBar: AppBar(
        title: Text('Manip $plantLabel · ${test.code}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: exportButtonTooltip(),
            onPressed: () => _exportAndShare(session, test, _plant, _calibration, standard, results),
          ),
        ],
      ),
      bottomNavigationBar: const KeyboardNavBar(),
      body: SafeArea(
        child: Column(
          children: [
            _buildSessionBanner(results, test, standard),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SessionHeaderCard(
                      session: session,
                      test: test,
                      plant: _plant,
                      extract: _extract,
                      standard: standard,
                    ),
                    const SizedBox(height: 18),
                    KeyedSubtree(
                      key: _resultsKey,
                      child: _ResultsCard(
                        results: results,
                        test: test,
                        standard: standard,
                        calibration: _calibration,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_expectedControlDO != null) ...[
                      _ControlSection(
                        expectedControlDO: _expectedControlDO!,
                        testCode: test.code,
                        savedValue: session.controlMeasurement,
                        onSave: _saveControl,
                      ),
                      const SizedBox(height: 18),
                    ],
                    _MeasurementsSection(
                      test: test,
                      replicates: session.replicates,
                      concentrations: _concentrations,
                      unit: unit,
                      filled: _filledMeasurements,
                      expected: _expectedMeasurements,
                      byKey: _byKey,
                      planKey: _planKey,
                      onSave: _saveMeasurement,
                      onToggleExcluded: _toggleExcluded,
                    ),
                  ],
                ),
              ),
            ),
            _CompleteBar(
              enabled: _canComplete,
              filledCount: _filledMeasurements,
              expectedCount: _expectedMeasurements,
              onPressed: _completeSession,
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionHeaderCard extends StatelessWidget {
  const _SessionHeaderCard({
    required this.session,
    required this.test,
    required this.plant,
    required this.extract,
    required this.standard,
  });

  final Session session;
  final TestDefinition test;
  final Plant? plant;
  final Extract? extract;
  final Standard? standard;

  @override
  Widget build(BuildContext context) {
    final plantLabel = session.plantCodeSnapshot ?? '?';
    final extractLabel = session.extractAbbrSnapshot ?? '?';
    final stdLabel = standard?.name ?? session.standardCodeSnapshot ?? 'standard non défini';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Pill(label: test.code, isPrimary: true),
              const SizedBox(width: 8),
              _Pill(label: plantLabel, isPrimary: true),
              const SizedBox(width: 8),
              _Pill(label: extractLabel),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            test.shortDescription,
            style: const TextStyle(fontSize: 14, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            'λ = ${test.wavelengthNm} nm · $stdLabel · ${test.reference}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (plant?.scientificName != null) ...[
            const SizedBox(height: 2),
            Text(
              plant!.scientificName!,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
            ),
          ],
          if (extract?.name != null) ...[
            const SizedBox(height: 2),
            Text(
              extract!.name,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

extension _SessionBanner on _SessionScreenState {
  Widget _buildSessionBanner(SessionResults results, TestDefinition test, Standard? standard) {
    final reg = results.sampleRegression;
    final isInhibition = test.regressionYType == RegressionYType.inhibitionPercent;
    Color statusColor;
    IconData statusIcon;
    if (reg == null) {
      statusColor = AppColors.textMuted;
      statusIcon = Icons.timelapse_rounded;
    } else if (reg.r2 >= 0.97) {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle_rounded;
    } else if (reg.r2 >= 0.90) {
      statusColor = AppColors.warning;
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = AppColors.danger;
      statusIcon = Icons.error_outline_rounded;
    }

    final stats = <BannerStat>[];
    if (reg != null) {
      if (isInhibition && results.ic50 != null) {
        stats.add(BannerStat(
          label: 'IC50',
          value: '${_pretty(results.ic50!)} ${test.concentrationUnit}',
          color: statusColor,
        ));
      } else if (!isInhibition && results.equivalentMgPerMl != null) {
        final eqLabel = standard?.equivalentLabel ?? 'STD';
        stats.add(BannerStat(
          label: 'Eq',
          value: '${_pretty(results.equivalentMgPerMl!)} mg $eqLabel/mL',
          color: statusColor,
        ));
      }
      stats.add(BannerStat(
        label: 'R²',
        value: reg.r2.toStringAsFixed(3),
        color: statusColor,
      ));
      stats.add(BannerStat(label: 'n', value: reg.n.toString()));
    }

    return ResultsBanner(
      stats: stats,
      statusColor: statusColor,
      statusIcon: statusIcon,
      message: reg == null ? 'Saisis ≥ 2 concentrations pour voir IC50/équivalents' : null,
      onScrollToTop: reg == null ? null : _scrollToResults,
    );
  }

  String _pretty(double v) {
    if (v.abs() >= 100) return v.toStringAsFixed(1);
    if (v.abs() >= 1) return v.toStringAsFixed(2);
    if (v.abs() >= 0.01) return v.toStringAsFixed(3);
    return v.toStringAsExponential(2);
  }
}

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({
    required this.results,
    required this.test,
    required this.standard,
    required this.calibration,
  });

  final SessionResults results;
  final TestDefinition test;
  final Standard? standard;
  final Calibration? calibration;

  Color _statusColor(double? r2) {
    if (r2 == null) return AppColors.textMuted;
    if (r2 >= 0.97) return AppColors.success;
    if (r2 >= 0.90) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final reg = results.sampleRegression;
    final isInhibition = test.regressionYType == RegressionYType.inhibitionPercent;
    final color = _statusColor(reg?.r2);
    final equivLabel = standard?.equivalentLabel ?? 'STD';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                reg == null ? Icons.timelapse_rounded : (reg.r2 >= 0.97 ? Icons.check_circle_rounded : Icons.warning_amber_rounded),
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Résultats live',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (calibration == null && test.supportsCalibration)
                const _MiniBadge(text: 'sans calib', color: AppColors.warning),
            ],
          ),
          const SizedBox(height: 8),
          if (reg == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Saisis au moins 2 concentrations pour voir la régression et l\'IC50.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            )
          else ...[
            if (isInhibition && results.ic50 != null) ...[
              _StatRow(
                label: 'IC50',
                value: '${_formatPretty(results.ic50!)} ${test.concentrationUnit}',
                color: color,
                isPrimary: true,
              ),
              const SizedBox(height: 4),
            ] else if (!isInhibition && results.equivalentMgPerMl != null) ...[
              _StatRow(
                label: 'Équivalent moyen',
                value: '${_formatPretty(results.equivalentMgPerMl!)} mg $equivLabel/mL',
                color: color,
                isPrimary: true,
              ),
              const SizedBox(height: 4),
            ],
            _StatRow(label: 'Pente', value: reg.slope.toStringAsFixed(4)),
            _StatRow(label: 'R²', value: reg.r2.toStringAsFixed(4), color: color),
            const SizedBox(height: 10),
            if (results.chartPoints.length >= 2)
              _MiniChart(
                points: results.chartPoints,
                regression: reg,
                yLabel: results.yLabel,
                xUnit: results.xUnit,
                ic50: isInhibition ? results.ic50 : null,
              ),
          ],
          if (results.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final w in results.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('⚠ $w',
                    style: const TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w500)),
              ),
          ],
          if (calibration != null) ...[
            const SizedBox(height: 6),
            Text(
              'Calibration : ${calibration!.name} (R²=${calibration!.r2?.toStringAsFixed(3) ?? "—"})',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  String _formatPretty(double v) {
    if (v.abs() >= 100) return v.toStringAsFixed(1);
    if (v.abs() >= 1) return v.toStringAsFixed(2);
    if (v.abs() >= 0.01) return v.toStringAsFixed(3);
    return v.toStringAsExponential(2);
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.color,
    this.isPrimary = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isPrimary ? 14 : 13,
              fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: isPrimary ? 17 : 14,
            fontWeight: FontWeight.w700,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _MiniChart extends StatelessWidget {
  const _MiniChart({
    required this.points,
    required this.regression,
    required this.yLabel,
    required this.xUnit,
    this.ic50,
  });

  final List<({double x, double y})> points;
  final RegressionResult regression;
  final String yLabel;
  final String xUnit;
  final double? ic50;

  @override
  Widget build(BuildContext context) {
    final xs = points.map((p) => p.x).toList()..sort();
    final ys = points.map((p) => p.y).toList()..sort();
    final xMin = xs.first;
    final xMax = xs.last;
    var yMin = ys.first;
    var yMax = ys.last;
    if (ic50 != null) {
      yMin = yMin > 0 ? 0 : yMin;
      yMax = yMax < 100 ? 100 : yMax;
    }
    final yPad = (yMax - yMin).abs() * 0.1;

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minX: xMin,
          maxX: xMax,
          minY: yMin - yPad,
          maxY: yMax + yPad,
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.textPrimary,
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                if (s.barIndex == 0) return null;
                return LineTooltipItem(
                  '${s.x.toStringAsFixed(s.x < 1 ? 4 : 2)} $xUnit\n'
                  '${s.y.toStringAsFixed(2)} $yLabel',
                  const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                );
              }).toList(),
            ),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: true,
            getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.outline, strokeWidth: 0.5),
            getDrawingVerticalLine: (_) => const FlLine(color: AppColors.outline, strokeWidth: 0.5)),
          borderData: FlBorderData(show: true, border: Border.all(color: AppColors.outline)),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              axisNameWidget: Text(yLabel, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              sideTitles: const SideTitles(showTitles: true, reservedSize: 32),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: Text(xUnit, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              sideTitles: const SideTitles(showTitles: true, reservedSize: 22),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          extraLinesData: ic50 != null
              ? ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 50,
                      color: AppColors.warning.withOpacity(0.6),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ],
                  verticalLines: [
                    VerticalLine(
                      x: ic50!,
                      color: AppColors.warning.withOpacity(0.6),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ],
                )
              : const ExtraLinesData(),
          lineBarsData: [
            LineChartBarData(
              spots: [
                FlSpot(xMin, regression.slope * xMin + regression.intercept),
                FlSpot(xMax, regression.slope * xMax + regression.intercept),
              ],
              isCurved: false,
              color: AppColors.primary,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: points.map((p) => FlSpot(p.x, p.y)).toList(),
              barWidth: 0,
              color: Colors.transparent,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.primary,
                  strokeColor: Colors.white,
                  strokeWidth: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.isPrimary = false});

  final String label;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isPrimary ? Colors.white : AppColors.primaryDark,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _ControlSection extends StatefulWidget {
  const _ControlSection({
    required this.expectedControlDO,
    required this.testCode,
    required this.savedValue,
    required this.onSave,
  });

  final double expectedControlDO;
  final String testCode;
  final double? savedValue;
  final Future<void> Function(double) onSave;

  @override
  State<_ControlSection> createState() => _ControlSectionState();
}

class _ControlSectionState extends State<_ControlSection> {
  late final TextEditingController _ctrl;
  ValidationResult? _result;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.savedValue != null ? widget.savedValue!.toStringAsFixed(3) : '',
    );
    if (widget.savedValue != null) {
      _result = validateControl(widget.savedValue!, widget.expectedControlDO);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onSubmit(String raw) async {
    if (raw.trim().isEmpty) {
      setState(() => _result = null);
      return;
    }
    final v = parseDecimal(raw);
    if (v == null) return;
    final result = validateControl(v, widget.expectedControlDO);
    setState(() => _result = result);
    if (result.level != ValidationLevel.error) {
      await widget.onSave(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Contrôle',
      subtitle: 'Attendu : DO ≈ ${widget.expectedControlDO.toStringAsFixed(3)}  ·  ${widget.testCode} + solvant',
      footer: _result?.message,
      footerLevel: _result?.level,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              textInputAction: TextInputAction.next,
              onChanged: _onSubmit,
              onSubmitted: _onSubmit,
              onEditingComplete: () => _onSubmit(_ctrl.text),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                labelText: 'DO contrôle',
                helperText: 'Virgule ou point au choix · sauvegarde auto',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _StatusBadge(result: _result),
        ],
      ),
    );
  }
}

class _MeasurementsSection extends StatelessWidget {
  const _MeasurementsSection({
    required this.test,
    required this.replicates,
    required this.concentrations,
    required this.unit,
    required this.filled,
    required this.expected,
    required this.byKey,
    required this.planKey,
    required this.onSave,
    required this.onToggleExcluded,
  });

  final TestDefinition test;
  final int replicates;
  final List<double> concentrations;
  final String unit;
  final int filled;
  final int expected;
  final Map<String, Measurement> byKey;
  final String Function(double, int) planKey;
  final Future<void> Function({
    required double concentration,
    required int replicate,
    required double rawDO,
  }) onSave;
  final Future<void> Function(double concentration, bool excluded) onToggleExcluded;

  @override
  Widget build(BuildContext context) {
    if (concentrations.isEmpty) {
      return const _SectionCard(
        title: 'Mesures',
        subtitle: 'Aucun plan par défaut pour ce test',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Saisie libre des concentrations à venir.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return _SectionCard(
      title: 'Mesures',
      subtitle: '$filled / $expected saisies · $replicates réplicats par concentration',
      child: Column(
        children: [
          for (var i = 0; i < concentrations.length; i++) ...[
            _ConcentrationGroup(
              concentration: concentrations[i],
              unit: unit,
              replicates: replicates,
              byKey: byKey,
              planKey: planKey,
              onSave: onSave,
              onToggleExcluded: onToggleExcluded,
            ),
            if (i < concentrations.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: AppColors.outline, height: 1),
              ),
          ],
        ],
      ),
    );
  }
}

class _ConcentrationGroup extends StatelessWidget {
  const _ConcentrationGroup({
    required this.concentration,
    required this.unit,
    required this.replicates,
    required this.byKey,
    required this.planKey,
    required this.onSave,
    required this.onToggleExcluded,
  });

  final double concentration;
  final String unit;
  final int replicates;
  final Map<String, Measurement> byKey;
  final String Function(double, int) planKey;
  final Future<void> Function({
    required double concentration,
    required int replicate,
    required double rawDO,
  }) onSave;
  final Future<void> Function(double concentration, bool excluded) onToggleExcluded;

  bool get _hasAnyMeasurement {
    for (var rep = 1; rep <= replicates; rep++) {
      if (byKey[planKey(concentration, rep)] != null) return true;
    }
    return false;
  }

  bool get _isExcluded {
    for (var rep = 1; rep <= replicates; rep++) {
      final m = byKey[planKey(concentration, rep)];
      if (m != null) return m.isExcluded;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                formatConcentration(concentration, unit),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _isExcluded ? AppColors.textMuted : AppColors.primaryDark,
                  decoration: _isExcluded ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (_hasAnyMeasurement) ...[
              Text(
                _isExcluded ? 'exclu' : 'régression',
                style: TextStyle(
                  fontSize: 11,
                  color: _isExcluded ? AppColors.danger : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Switch(
                value: !_isExcluded,
                onChanged: (v) => onToggleExcluded(concentration, !v),
                activeColor: AppColors.primary,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        for (var rep = 1; rep <= replicates; rep++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Opacity(
              opacity: _isExcluded ? 0.5 : 1,
              child: _ReplicateRow(
                replicate: rep,
                existing: byKey[planKey(concentration, rep)],
                onSave: (rawDO) => onSave(
                  concentration: concentration,
                  replicate: rep,
                  rawDO: rawDO,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReplicateRow extends StatefulWidget {
  const _ReplicateRow({
    required this.replicate,
    required this.existing,
    required this.onSave,
  });

  final int replicate;
  final Measurement? existing;
  final Future<void> Function(double) onSave;

  @override
  State<_ReplicateRow> createState() => _ReplicateRowState();
}

class _ReplicateRowState extends State<_ReplicateRow> {
  late final TextEditingController _ctrl;
  ValidationResult? _result;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.existing != null
          ? widget.existing!.rawDO.toStringAsFixed(3)
          : '',
    );
    if (widget.existing != null) {
      _result = validateDO(widget.existing!.rawDO);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onSubmit(String raw) async {
    if (raw.trim().isEmpty) {
      setState(() => _result = null);
      return;
    }
    final v = parseDecimal(raw);
    if (v == null) return;
    final result = validateDO(v);
    setState(() => _result = result);
    if (result.level != ValidationLevel.error) {
      await widget.onSave(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          alignment: Alignment.center,
          child: Text(
            'R${widget.replicate}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            textInputAction: TextInputAction.next,
            onChanged: _onSubmit,
            onSubmitted: _onSubmit,
            onEditingComplete: () => _onSubmit(_ctrl.text),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: 'DO',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _StatusBadge(result: _result),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.footerLevel,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? footer;
  final ValidationLevel? footerLevel;

  Color _footerColor() {
    switch (footerLevel) {
      case ValidationLevel.warning:
        return AppColors.warning;
      case ValidationLevel.error:
        return AppColors.danger;
      case ValidationLevel.ok:
      case null:
        return AppColors.textSecondary;
    }
  }

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
          if (footer != null) ...[
            const SizedBox(height: 8),
            Text(
              footer!,
              style: TextStyle(fontSize: 13, color: _footerColor(), fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.result});

  final ValidationResult? result;

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return const SizedBox(width: 28, height: 28);
    }
    final color = switch (result!.level) {
      ValidationLevel.ok => AppColors.success,
      ValidationLevel.warning => AppColors.warning,
      ValidationLevel.error => AppColors.danger,
    };
    final icon = switch (result!.level) {
      ValidationLevel.ok => Icons.check_circle_rounded,
      ValidationLevel.warning => Icons.warning_amber_rounded,
      ValidationLevel.error => Icons.error_outline_rounded,
    };
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _CompleteBar extends StatelessWidget {
  const _CompleteBar({
    required this.enabled,
    required this.filledCount,
    required this.expectedCount,
    required this.onPressed,
  });

  final bool enabled;
  final int filledCount;
  final int expectedCount;
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
              const Text(
                'Terminer la manip',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$filledCount/$expectedCount',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
