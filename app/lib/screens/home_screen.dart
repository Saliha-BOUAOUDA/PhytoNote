import 'package:flutter/material.dart';

import '../config/catalog.dart';
import '../data/calibration_repository.dart';
import '../data/catalog_cache.dart';
import '../data/session_repository.dart';
import '../theme.dart';
import 'calibrations_list_screen.dart';
import 'catalog_screen.dart';
import 'new_session_screen.dart';
import 'sessions_list_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sessionRepo = SessionRepository();
  final _calibrationRepo = CalibrationRepository();

  int? _activeSessions;
  int? _calibrations;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _refreshCounts();
  }

  Future<void> _refreshCounts() async {
    try {
      final active = await _sessionRepo.count(statusFilter: SessionStatus.active);
      final calibs = await _calibrationRepo.count();
      if (!mounted) return;
      setState(() {
        _activeSessions = active;
        _calibrations = calibs;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadFailed = true);
    }
  }

  Future<void> _openNewSession() async {
    await Navigator.of(context).push<bool?>(
      MaterialPageRoute(builder: (_) => const NewSessionScreen()),
    );
    if (!mounted) return;
    await _refreshCounts();
  }

  Future<void> _openCalibrations() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CalibrationsListScreen()),
    );
    if (!mounted) return;
    await _refreshCounts();
  }

  Future<void> _openSessionsList() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SessionsListScreen()),
    );
    if (!mounted) return;
    await _refreshCounts();
  }

  Future<void> _openCatalog() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CatalogScreen()),
    );
    if (!mounted) return;
    await CatalogCache.refresh();
    if (!mounted) return;
    await _refreshCounts();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  String _sessionsHint() {
    if (_loadFailed) return 'État indisponible';
    if (_activeSessions == null) return '...';
    if (_activeSessions == 0) return 'Aucune manip en cours';
    if (_activeSessions == 1) return '1 manip en cours';
    return '$_activeSessions manips en cours';
  }

  String _calibrationsHint() {
    if (_loadFailed) return 'État indisponible';
    if (_calibrations == null) return '...';
    if (_calibrations == 0) return 'Aucun lot enregistré';
    if (_calibrations == 1) return '1 lot enregistré';
    return '$_calibrations lots enregistrés';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _BrandHeader(),
              const SizedBox(height: 28),
              _PrimaryActionCard(
                title: 'Nouvelle manip',
                subtitle: 'DPPH · FRAP · CAT · TPC · TFC · ABTS',
                icon: Icons.science_outlined,
                onTap: _openNewSession,
              ),
              const SizedBox(height: 16),
              _SecondaryActionTile(
                icon: Icons.bookmark_outline,
                title: 'Reprendre une manip',
                hint: _sessionsHint(),
                onTap: _openSessionsList,
              ),
              const SizedBox(height: 12),
              _SecondaryActionTile(
                icon: Icons.straighten_outlined,
                title: 'Calibrations',
                hint: _calibrationsHint(),
                onTap: _openCalibrations,
              ),
              const SizedBox(height: 12),
              _SecondaryActionTile(
                icon: Icons.menu_book_outlined,
                title: 'Catalogue',
                hint: 'Plantes · Extraits · Standards · Bactéries · Enzymes',
                onTap: _openCatalog,
              ),
              const SizedBox(height: 12),
              _SecondaryActionTile(
                icon: Icons.cloud_sync_outlined,
                title: 'Synchroniser',
                hint: 'Jamais synchronisé',
                onTap: () => _comingSoon(context, 'Synchroniser'),
              ),
              const SizedBox(height: 12),
              _SecondaryActionTile(
                icon: Icons.settings_outlined,
                title: 'Paramètres',
                hint: 'Version · langue · aide',
                onTap: _openSettings,
              ),
              const SizedBox(height: 24),
              const _FooterTag(),
            ],
          ),
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('$label — bientôt disponible')));
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.biotech_outlined, color: AppColors.primaryDark, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PhytoNote',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 2),
              Text(
                'Saisie validée DO · spectrophotométrie UV',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const _StatusPill(label: 'Hors ligne', isOffline: true),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.isOffline});

  final String label;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final color = isOffline ? AppColors.warning : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: Colors.white, size: 36),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.85),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: Colors.white.withOpacity(0.9), size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionTile extends StatelessWidget {
  const _SecondaryActionTile({
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primaryDark, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(hint, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterTag extends StatelessWidget {
  const _FooterTag();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.outline.withOpacity(0.4),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'v1.2.0 · paramètres 🟢',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
