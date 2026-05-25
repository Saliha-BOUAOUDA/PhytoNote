import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/version.dart';
import '../theme.dart';

const _githubRepo = 'https://github.com/Saliha-BOUAOUDA/PhytoNote';
const _releasesUrl = '$_githubRepo/releases';
const _newIssueUrl = '$_githubRepo/issues/new/choose';
const _licenseUrl = '$_githubRepo/blob/main/LICENSE';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final String _version = kAppVersion;
  final String _build = kAppBuildNumber;
  String _language = 'fr';

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const _SectionHeader(label: 'À propos'),
            _AboutCard(version: _version, buildNumber: _build),
            const SizedBox(height: 24),
            const _SectionHeader(label: 'Aide'),
            _LinkTile(
              icon: Icons.event_note_outlined,
              title: 'Notes de version',
              subtitle: 'Toutes les versions publiées sur GitHub',
              onTap: () => _open(_releasesUrl),
            ),
            const SizedBox(height: 8),
            _LinkTile(
              icon: Icons.code_outlined,
              title: 'Code source',
              subtitle: 'Repository GitHub Saliha-BOUAOUDA/PhytoNote',
              onTap: () => _open(_githubRepo),
            ),
            const SizedBox(height: 8),
            _LinkTile(
              icon: Icons.bug_report_outlined,
              title: 'Signaler un bug',
              subtitle: 'Ouvrir une issue sur GitHub',
              onTap: () => _open(_newIssueUrl),
            ),
            const SizedBox(height: 24),
            const _SectionHeader(label: 'Langue'),
            _LanguagePicker(
              selected: _language,
              onChanged: (v) => setState(() => _language = v),
            ),
            const SizedBox(height: 24),
            const _SectionHeader(label: 'License'),
            _LinkTile(
              icon: Icons.workspace_premium_outlined,
              title: 'GPL-3.0-or-later',
              subtitle: 'Copyleft fort — voir le texte complet',
              onTap: () => _open(_licenseUrl),
            ),
            const SizedBox(height: 32),
            const Center(
              child: Text(
                '© 2026 Saliha BOUAOUDA',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 10),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.biotech_outlined, color: AppColors.primaryDark, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'PhytoNote',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Version $version${buildNumber.isEmpty ? "" : " (build $buildNumber)"}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Saisie validée pour spectrophotométrie UV — antioxydants, antibactérien, anti-inflammatoire.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: AppColors.primaryDark, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LangChip(
                flag: '🇫🇷',
                label: 'Français',
                value: 'fr',
                isSelected: selected == 'fr',
                isAvailable: true,
                onTap: () => onChanged('fr'),
              ),
              _LangChip(
                flag: '🇬🇧',
                label: 'English',
                value: 'en',
                isSelected: false,
                isAvailable: false,
                onTap: () {},
              ),
              _LangChip(
                flag: '🇸🇦',
                label: 'العربية',
                value: 'ar',
                isSelected: false,
                isAvailable: false,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'L\'internationalisation complète sera ajoutée dans une prochaine version.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.flag,
    required this.label,
    required this.value,
    required this.isSelected,
    required this.isAvailable,
    required this.onTap,
  });

  final String flag;
  final String label;
  final String value;
  final bool isSelected;
  final bool isAvailable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isSelected
        ? AppColors.primary
        : (isAvailable ? AppColors.surfaceElevated : AppColors.outline.withOpacity(0.3));
    final fg = isSelected
        ? Colors.white
        : (isAvailable ? AppColors.textPrimary : AppColors.textMuted);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: isAvailable ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg),
            ),
            if (!isAvailable) ...[
              const SizedBox(width: 6),
              Text(
                '· à venir',
                style: TextStyle(fontSize: 11, color: fg.withOpacity(0.7), fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
