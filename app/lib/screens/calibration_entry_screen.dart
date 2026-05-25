import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/catalog.dart';
import '../data/calibration_repository.dart';
import '../data/catalog_cache.dart';
import '../data/catalog_models.dart';
import '../data/models.dart';
import '../services/excel_export.dart';
import '../services/regression.dart';
import '../theme.dart';
import '../widgets/export_snackbar.dart';
import '../widgets/keyboard_nav_bar.dart';
import '../widgets/results_banner.dart';

class CalibrationEntryScreen extends StatefulWidget {
  const CalibrationEntryScreen({super.key, required this.calibrationId});

  final String calibrationId;

  @override
  State<CalibrationEntryScreen> createState() => _CalibrationEntryScreenState();
}

class _CalibrationEntryScreenState extends State<CalibrationEntryScreen> {
  final _repo = CalibrationRepository();
  final _scrollCtrl = ScrollController();
  final _detailKey = GlobalKey();

  Calibration? _calibration;
  TestDefinition? _test;
  Standard? _standard;
  List<double> _concentrations = const [];
  Map<double, CalibrationPoint> _byConc = {};
  bool _loading = true;
  String? _loadError;
  bool _saving = false;

  int get _replicates => _calibration?.replicates ?? 3;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToDetail() {
    final ctx = _detailKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  Future<void> _exportAndShare(RegressionResult? regression) async {
    try {
      final cal = _calibration;
      final test = _test;
      if (cal == null || test == null) return;
      final pointsList = _concentrations
          .map((c) => _byConc[c])
          .where((p) => p != null)
          .cast<CalibrationPoint>()
          .toList();
      final file = await exportCalibrationToExcel(
        calibration: cal,
        test: test,
        standard: _standard,
        points: pointsList,
        regression: regression,
      );
      if (!mounted) return;
      showExportSuccessSnackBar(context, file);
    } catch (e) {
      if (!mounted) return;
      showExportErrorSnackBar(context, e);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cal = await _repo.byId(widget.calibrationId);
      if (cal == null) {
        setState(() {
          _loading = false;
          _loadError = 'Calibration introuvable';
        });
        return;
      }
      final test = findTestByCode(cal.testType);
      if (test == null) {
        setState(() {
          _loading = false;
          _loadError = 'Test inconnu : ${cal.testType}';
        });
        return;
      }
      final std = CatalogCache.findStandardByAbbr(cal.standardCompound);
      final concs = cal.concentrations.isNotEmpty
          ? cal.concentrations
          : generateCalibrationConcentrations(test, kDefaultCalibrationDilutions);
      final existing = await _repo.pointsFor(cal.id);
      setState(() {
        _calibration = cal;
        _test = test;
        _standard = std;
        _concentrations = concs;
        _byConc = {for (final p in existing) p.concentration: p};
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _loadError = 'Erreur de chargement : $e';
      });
    }
  }

  Future<void> _saveReplicate(double concentration, int repIndex, double do_) async {
    final existing = _byConc[concentration];
    final reps = List<double?>.from(existing?.doReplicates ?? const []);
    while (reps.length <= repIndex) {
      reps.add(null);
    }
    reps[repIndex] = do_;
    final point = CalibrationPoint(
      calibrationId: widget.calibrationId,
      concentration: concentration,
      doReplicates: reps,
      retainedForFit: existing?.retainedForFit ?? true,
    );
    await _repo.upsertPoint(point);
    setState(() => _byConc[concentration] = point);
  }

  Future<void> _toggleRetained(double concentration, bool retained) async {
    final existing = _byConc[concentration];
    if (existing == null) return;
    final updated = CalibrationPoint(
      calibrationId: widget.calibrationId,
      concentration: concentration,
      doReplicates: existing.doReplicates,
      retainedForFit: retained,
    );
    await _repo.upsertPoint(updated);
    setState(() => _byConc[concentration] = updated);
  }

  RegressionResult? get _liveRegression {
    final pts = _toRegressionPoints(retainedOnly: true);
    return linearRegression(pts);
  }

  List<({double x, double y})> _toRegressionPoints({required bool retainedOnly}) {
    final pts = <({double x, double y})>[];
    final cal = _calibration;
    final test = _test;
    if (cal == null || test == null) return pts;
    for (final c in _concentrations) {
      final p = _byConc[c];
      if (p == null) continue;
      if (retainedOnly && !p.retainedForFit) continue;
      final reps = p.validReplicates.toList();
      if (reps.isEmpty) continue;
      final mean = reps.reduce((a, b) => a + b) / reps.length;
      final y = test.regressionYType == RegressionYType.inhibitionPercent && cal.controlDO != null && cal.controlDO! != 0
          ? (1 - mean / cal.controlDO!) * 100
          : mean;
      pts.add((x: c, y: y));
    }
    return pts;
  }

  Future<void> _saveCalibration() async {
    final reg = _liveRegression;
    if (reg == null) return;
    setState(() => _saving = true);
    final updated = _calibration!.copyWith(
      slope: reg.slope,
      intercept: reg.intercept,
      r2: reg.r2,
      lastUsed: DateTime.now(),
    );
    await _repo.update(updated);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_loadError!))),
      );
    }

    final test = _test!;
    final cal = _calibration!;
    final reg = _liveRegression;
    final yType = test.regressionYType;

    return Scaffold(
      appBar: AppBar(
        title: Text('Calibration ${test.code}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: exportButtonTooltip(),
            onPressed: () => _exportAndShare(reg),
          ),
        ],
      ),
      bottomNavigationBar: const KeyboardNavBar(),
      body: SafeArea(
        child: Column(
          children: [
            _buildBanner(reg, test),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(calibration: cal, standard: _standard),
                    const SizedBox(height: 16),
                    KeyedSubtree(
                      key: _detailKey,
                      child: _RegressionCard(
                        result: reg,
                        yType: yType,
                        unit: test.concentrationUnit,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (reg != null && _toRegressionPoints(retainedOnly: false).length >= 2)
                      _CalibrationChart(
                        points: _toRegressionPoints(retainedOnly: false),
                        retainedPoints: _toRegressionPoints(retainedOnly: true),
                        regression: reg,
                        yLabel: yType == RegressionYType.inhibitionPercent ? '% inhibition' : 'DO',
                        xUnit: test.concentrationUnit,
                      ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Saisie des points',
                      subtitle: '${_concentrations.length} concentrations · $_replicates réplicats · virgule ou point · sauvegarde auto',
                      child: Column(
                        children: [
                          for (var i = 0; i < _concentrations.length; i++) ...[
                            _PointRow(
                              concentration: _concentrations[i],
                              unit: test.concentrationUnit,
                              point: _byConc[_concentrations[i]],
                              replicates: _replicates,
                              onSave: _saveReplicate,
                              onToggleRetained: _toggleRetained,
                            ),
                            if (i < _concentrations.length - 1)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(height: 1, color: AppColors.outline),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _SaveBar(
              regression: reg,
              isLoading: _saving,
              onPressed: _saveCalibration,
            ),
          ],
        ),
      ),
    );
  }
}

extension _CalBanner on _CalibrationEntryScreenState {
  Widget _buildBanner(RegressionResult? reg, TestDefinition test) {
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
      stats.add(BannerStat(label: 'R²', value: reg.r2.toStringAsFixed(3), color: statusColor));
      stats.add(BannerStat(label: 'pente', value: reg.slope.toStringAsFixed(3)));
      stats.add(BannerStat(label: 'b', value: reg.intercept.toStringAsFixed(3)));
      stats.add(BannerStat(label: 'n', value: reg.n.toString()));
    }

    return ResultsBanner(
      stats: stats,
      statusColor: statusColor,
      statusIcon: statusIcon,
      message: reg == null ? 'Saisis ≥ 2 points pour voir la régression' : null,
      onScrollToTop: reg == null ? null : _scrollToDetail,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.calibration, required this.standard});

  final Calibration calibration;
  final Standard? standard;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(calibration.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
          const SizedBox(height: 4),
          Text(
            'Lot ${calibration.reagentBatchNumber ?? "non précisé"} · ouvert le ${_formatDate(calibration.dateOpenedFlask)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (calibration.controlDO != null) ...[
            const SizedBox(height: 2),
            Text(
              'DO contrôle : ${calibration.controlDO!.toStringAsFixed(3)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          if (standard?.equivalentLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              'Équivalents en : ${standard!.equivalentLabel}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _RegressionCard extends StatelessWidget {
  const _RegressionCard({
    required this.result,
    required this.yType,
    required this.unit,
  });

  final RegressionResult? result;
  final RegressionYType yType;
  final String unit;

  Color get _statusColor {
    final r = result;
    if (r == null) return AppColors.textMuted;
    if (r.r2 >= 0.97) return AppColors.success;
    if (r.r2 >= 0.90) return AppColors.warning;
    return AppColors.danger;
  }

  String get _statusLabel {
    final r = result;
    if (r == null) return 'En attente de points';
    if (r.r2 >= 0.97) return 'Linéarité validée';
    if (r.r2 >= 0.90) return 'Linéarité moyenne';
    return 'Linéarité insuffisante';
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _statusColor.withOpacity(0.4), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                r != null && r.r2 >= 0.97
                    ? Icons.check_circle_rounded
                    : (r != null && r.r2 >= 0.90 ? Icons.warning_amber_rounded : Icons.error_outline_rounded),
                color: _statusColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_statusLabel,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _statusColor)),
              ),
              if (r != null)
                Text('n=${r.n}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          if (r != null) ...[
            _Stat(label: 'Pente (slope)', value: r.slope.toStringAsFixed(4), unit: yType == RegressionYType.inhibitionPercent ? '%/$unit' : '/$unit'),
            const SizedBox(height: 4),
            _Stat(label: 'Ordonnée (intercept)', value: r.intercept.toStringAsFixed(4)),
            const SizedBox(height: 4),
            _Stat(label: 'R²', value: r.r2.toStringAsFixed(4), valueColor: _statusColor),
            const SizedBox(height: 6),
            Text(
              r.formatEquation(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppColors.textSecondary),
            ),
          ] else
            const Text(
              'Saisis au moins 2 points pour voir la régression.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.unit, this.valueColor});

  final String label;
  final String value;
  final String? unit;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
        if (unit != null) ...[
          const SizedBox(width: 4),
          Text(unit!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ],
    );
  }
}

class _CalibrationChart extends StatelessWidget {
  const _CalibrationChart({
    required this.points,
    required this.retainedPoints,
    required this.regression,
    required this.yLabel,
    required this.xUnit,
  });

  final List<({double x, double y})> points;
  final List<({double x, double y})> retainedPoints;
  final RegressionResult regression;
  final String yLabel;
  final String xUnit;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final xs = points.map((p) => p.x).toList()..sort();
    final ys = points.map((p) => p.y).toList()..sort();
    final xMin = xs.first;
    final xMax = xs.last;
    final yMin = ys.first;
    final yMax = ys.last;
    final yPad = (yMax - yMin) * 0.1;

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
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
                if (s.barIndex == 0) return null; // skip regression line
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
              axisNameWidget: Text(yLabel, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              sideTitles: const SideTitles(showTitles: true, reservedSize: 36),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: Text(xUnit, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              sideTitles: const SideTitles(showTitles: true, reservedSize: 26),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
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
                getDotPainter: (spot, _, __, ___) {
                  final retained = retainedPoints.any(
                    (p) => (p.x - spot.x).abs() < 1e-9 && (p.y - spot.y).abs() < 1e-9,
                  );
                  return FlDotCirclePainter(
                    radius: 4,
                    color: retained ? AppColors.primary : AppColors.textMuted,
                    strokeColor: Colors.white,
                    strokeWidth: 1,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({
    required this.concentration,
    required this.unit,
    required this.point,
    required this.replicates,
    required this.onSave,
    required this.onToggleRetained,
  });

  final double concentration;
  final String unit;
  final CalibrationPoint? point;
  final int replicates;
  final Future<void> Function(double, int, double) onSave;
  final Future<void> Function(double, bool) onToggleRetained;

  @override
  Widget build(BuildContext context) {
    final retained = point?.retainedForFit ?? true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                formatConcentration(concentration, unit),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
              ),
            ),
            Switch(
              value: retained,
              onChanged: point == null ? null : (v) => onToggleRetained(concentration, v),
              activeColor: AppColors.primary,
            ),
            const SizedBox(width: 4),
            const Text('régression', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var rep = 0; rep < replicates; rep++) ...[
              Expanded(
                child: _ReplicateField(
                  concentration: concentration,
                  repIndex: rep,
                  initial: (point != null && point!.doReplicates.length > rep)
                      ? point!.doReplicates[rep]
                      : null,
                  onSave: onSave,
                ),
              ),
              if (rep < replicates - 1) const SizedBox(width: 10),
            ],
          ],
        ),
      ],
    );
  }
}

class _ReplicateField extends StatefulWidget {
  const _ReplicateField({
    required this.concentration,
    required this.repIndex,
    required this.initial,
    required this.onSave,
  });

  final double concentration;
  final int repIndex;
  final double? initial;
  final Future<void> Function(double, int, double) onSave;

  @override
  State<_ReplicateField> createState() => _ReplicateFieldState();
}

class _ReplicateFieldState extends State<_ReplicateField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial?.toStringAsFixed(3) ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    final raw = _ctrl.text.trim().replaceAll(',', '.');
    final v = double.tryParse(raw);
    if (v == null) return;
    await widget.onSave(widget.concentration, widget.repIndex, v);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      textInputAction: TextInputAction.next,
      onChanged: (_) => _persist(),
      onEditingComplete: _persist,
      onSubmitted: (_) => _persist(),
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: 'R${widget.repIndex + 1}',
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

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
        ],
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.regression, required this.isLoading, required this.onPressed});

  final RegressionResult? regression;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final canSave = regression != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SizedBox(
        height: 64,
        child: ElevatedButton(
          onPressed: canSave && !isLoading ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.outline,
            disabledForegroundColor: AppColors.textMuted,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: isLoading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Enregistrer la calibration', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    if (regression != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('R²=${regression!.r2.toStringAsFixed(3)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
