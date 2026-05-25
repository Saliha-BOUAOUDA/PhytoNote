import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/catalog.dart';
import '../data/catalog_cache.dart';
import '../data/catalog_models.dart';
import '../data/measurement_repository.dart';
import '../data/models.dart';
import '../data/session_repository.dart';
import '../theme.dart';
import '../widgets/scientific_label.dart';
import 'antibac_session_screen.dart';
import 'new_session_screen.dart';
import 'session_screen.dart';

class SessionsListScreen extends StatefulWidget {
  const SessionsListScreen({super.key});

  @override
  State<SessionsListScreen> createState() => _SessionsListScreenState();
}

class _SessionsListScreenState extends State<SessionsListScreen> {
  final _sessionRepo = SessionRepository();
  final _measurementRepo = MeasurementRepository();

  List<_SessionWithMeta> _items = const [];
  bool _loading = true;
  String _filter = 'all'; // all | active | completed

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final sessions = await _sessionRepo.all();
    final withMeta = <_SessionWithMeta>[];
    for (final s in sessions) {
      final count = await _measurementRepo.count(s.id);
      withMeta.add(_SessionWithMeta(session: s, measurementCount: count));
    }
    if (!mounted) return;
    setState(() {
      _items = withMeta;
      _loading = false;
    });
  }

  List<_SessionWithMeta> get _filteredItems {
    if (_filter == 'all') return _items;
    return _items.where((m) => m.session.status == _filter).toList();
  }

  Future<void> _openNew() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NewSessionScreen()),
    );
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _resume(_SessionWithMeta meta) async {
    final test = findTestByCode(meta.session.testType);
    final isAntibac = test?.requiresPlateView ?? false;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => isAntibac
            ? AntibacSessionScreen(sessionId: meta.session.id)
            : SessionScreen(sessionId: meta.session.id),
      ),
    );
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _confirmDelete(_SessionWithMeta meta) async {
    final s = meta.session;
    final extractLabel = s.extractAbbrSnapshot ?? '?';
    final plantLabel = s.plantCodeSnapshot ?? '?';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la manip ?'),
        content: Text(
          '${s.testType} · $plantLabel · $extractLabel\n'
          '${meta.measurementCount} mesure(s) seront aussi supprimées.\n\n'
          'Cette action est irréversible.',
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
    await _sessionRepo.deleteById(s.id);
    if (!mounted) return;
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Manip supprimée')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes manips'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _FilterChip(label: 'Toutes', value: 'all', currentFilter: _filter, onTap: (v) => setState(() => _filter = v)),
                const SizedBox(width: 8),
                _FilterChip(label: 'En cours', value: SessionStatus.active, currentFilter: _filter, onTap: (v) => setState(() => _filter = v)),
                const SizedBox(width: 8),
                _FilterChip(label: 'Terminées', value: SessionStatus.completed, currentFilter: _filter, onTap: (v) => setState(() => _filter = v)),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNew,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle manip'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : filtered.isEmpty
              ? _EmptyState(filter: _filter, onCreate: _openNew)
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _SessionTile(
                      meta: filtered[i],
                      onTap: () => _resume(filtered[i]),
                      onDelete: () => _confirmDelete(filtered[i]),
                    ),
                  ),
                ),
    );
  }
}

class _SessionWithMeta {
  final Session session;
  final int measurementCount;
  _SessionWithMeta({required this.session, required this.measurementCount});
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.currentFilter,
    required this.onTap,
  });

  final String label;
  final String value;
  final String currentFilter;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == currentFilter;
    return InkWell(
      onTap: () => onTap(value),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.outline),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter, required this.onCreate});

  final String filter;
  final VoidCallback onCreate;

  String get _message {
    switch (filter) {
      case SessionStatus.active:
        return 'Aucune manip en cours';
      case SessionStatus.completed:
        return 'Aucune manip terminée';
      default:
        return 'Aucune manip enregistrée';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.science_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 18),
            Text(_message, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Créer une manip'),
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

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.meta,
    required this.onTap,
    required this.onDelete,
  });

  final _SessionWithMeta meta;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  Color get _statusColor {
    switch (meta.session.status) {
      case SessionStatus.active:
        return AppColors.primary;
      case SessionStatus.completed:
        return AppColors.success;
      case SessionStatus.aborted:
        return AppColors.textMuted;
      default:
        return AppColors.textMuted;
    }
  }

  String get _statusLabel {
    switch (meta.session.status) {
      case SessionStatus.active:
        return 'En cours';
      case SessionStatus.completed:
        return 'Terminée';
      case SessionStatus.aborted:
        return 'Abandonnée';
      default:
        return meta.session.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = meta.session;
    final std = CatalogCache.findStandard(s.standardId);
    final bacteria = CatalogCache.findBacteria(s.bacteriaId);

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
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Pill(label: s.testType, isPrimary: true),
                        if (s.plantCodeSnapshot != null)
                          _Pill(label: s.plantCodeSnapshot!, isPrimary: true),
                        if (s.extractAbbrSnapshot != null)
                          _Pill(label: s.extractAbbrSnapshot!),
                        if (bacteria != null)
                          _BacteriaPill(bacteria: bacteria)
                        else if (s.bacteriaCodeSnapshot != null)
                          _Pill(label: s.bacteriaCodeSnapshot!),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 22),
                    color: AppColors.textMuted,
                    tooltip: 'Supprimer',
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Démarrée ${_relativeDate(s.startedAt)}'
                '${s.completedAt != null ? " · terminée ${_relativeDate(s.completedAt!)}" : ""}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _Mini(label: 'mesures', value: meta.measurementCount.toString()),
                  if (std != null) _Mini(label: 'std', value: std.abbreviation),
                  if (s.controlMeasurement != null)
                    _Mini(label: 'ctrl', value: s.controlMeasurement!.toStringAsFixed(3)),
                  if (s.ic50UgPerMl != null)
                    _Mini(label: 'IC50', value: s.ic50UgPerMl!.toStringAsFixed(2)),
                  if (s.cmiUgPerMl != null)
                    _Mini(label: 'CMI', value: s.cmiUgPerMl!.toStringAsFixed(3)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'hier';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return DateFormat('d MMM yyyy', 'fr_FR').format(d);
  }
}

class _BacteriaPill extends StatelessWidget {
  const _BacteriaPill({required this.bacteria});
  final Bacteria bacteria;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withOpacity(0.6), width: 1),
      ),
      child: ScientificLabel(
        text: bacteria.abbreviation,
        italic: true,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
          letterSpacing: 0.2,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withOpacity(0.6), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isPrimary ? Colors.white : AppColors.primaryDark,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
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
        Text('$label ', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
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
