import 'package:flutter/material.dart';

import '../data/calibration_repository.dart';
import '../data/catalog_cache.dart';
import '../data/models.dart';
import '../theme.dart';
import 'calibration_entry_screen.dart';
import 'new_calibration_screen.dart';

class CalibrationsListScreen extends StatefulWidget {
  const CalibrationsListScreen({super.key});

  @override
  State<CalibrationsListScreen> createState() => _CalibrationsListScreenState();
}

class _CalibrationsListScreenState extends State<CalibrationsListScreen> {
  final _repo = CalibrationRepository();
  List<Calibration> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final items = await _repo.all();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NewCalibrationScreen()),
    );
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _openEntry(Calibration c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CalibrationEntryScreen(calibrationId: c.id)),
    );
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _confirmDelete(Calibration c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la calibration ?'),
        content: Text(
          '${c.name}\n\nLes points saisis seront aussi supprimés.\n\nCette action est irréversible.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repo.deleteById(c.id);
    if (!mounted) return;
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calibration supprimée')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calibrations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle calibration'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _EmptyState(onCreate: _openCreate)
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _CalibrationTile(
                      calibration: _items[i],
                      onTap: () => _openEntry(_items[i]),
                      onDelete: () => _confirmDelete(_items[i]),
                    ),
                  ),
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.straighten_rounded, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 18),
            Text('Aucune calibration enregistrée',
                style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text(
              'Une calibration valide (R² ≥ 0.97) est nécessaire pour calculer les IC50/EC50/équivalents de tes manips.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Créer la première'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalibrationTile extends StatelessWidget {
  const _CalibrationTile({
    required this.calibration,
    required this.onTap,
    required this.onDelete,
  });

  final Calibration calibration;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  Color get _statusColor {
    if (calibration.r2 == null) return AppColors.textMuted;
    if (calibration.isExpired) return AppColors.warning;
    if (calibration.r2! >= 0.97) return AppColors.success;
    if (calibration.r2! >= 0.90) return AppColors.warning;
    return AppColors.danger;
  }

  String get _statusLabel {
    if (calibration.r2 == null) return 'Incomplet';
    if (calibration.isExpired) return 'Expirée';
    if (calibration.r2! >= 0.97) return 'Valide';
    if (calibration.r2! >= 0.90) return 'Limite';
    return 'Insuffisante';
  }

  @override
  Widget build(BuildContext context) {
    final std = CatalogCache.findStandardByAbbr(calibration.standardCompound);
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${calibration.testType} · ${std?.name ?? calibration.standardCompound}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _statusColor.withOpacity(0.4)),
                    ),
                    child: Text(_statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _statusColor,
                        )),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 22),
                    color: AppColors.textMuted,
                    tooltip: 'Supprimer',
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Lot ${calibration.reagentBatchNumber ?? "—"}  ·  ouvert le ${_fmt(calibration.dateOpenedFlask)}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (calibration.r2 != null) ...[
                    _Mini(label: 'R²', value: calibration.r2!.toStringAsFixed(3)),
                    const SizedBox(width: 14),
                  ],
                  if (calibration.slope != null) ...[
                    _Mini(label: 'pente', value: calibration.slope!.toStringAsFixed(3)),
                    const SizedBox(width: 14),
                  ],
                  if (calibration.controlDO != null)
                    _Mini(label: 'ctrl', value: calibration.controlDO!.toStringAsFixed(3)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        Text(value,
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      ],
    );
  }
}
