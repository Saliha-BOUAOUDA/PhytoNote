import 'package:flutter/material.dart';

import '../theme.dart';

class BannerStat {
  final String label;
  final String value;
  final Color? color;
  const BannerStat({required this.label, required this.value, this.color});
}

/// Bandeau compact qui colle sous l'AppBar pour afficher les indicateurs clés
/// (R², IC50, CMI, équivalents…) pendant que l'utilisatrice scroll dans le
/// formulaire de saisie. Ne prend pas plus de ~52 dp de hauteur.
class ResultsBanner extends StatelessWidget {
  const ResultsBanner({
    super.key,
    required this.stats,
    required this.statusColor,
    this.statusIcon,
    this.message,
    this.onScrollToTop,
  });

  /// Couleurs verts/orange/rouge selon le statut du calcul.
  final Color statusColor;

  /// Icône d'état (check / warning / hourglass…). Si null, pas d'icône.
  final IconData? statusIcon;

  /// Indicateurs à afficher sur la ligne. Si vide, affiche `message`.
  final List<BannerStat> stats;

  /// Texte de fallback si aucun indicateur calculé encore.
  final String? message;

  /// Si défini, le bandeau devient cliquable et scroll vers le détail (graph).
  final VoidCallback? onScrollToTop;

  @override
  Widget build(BuildContext context) {
    final clickable = onScrollToTop != null;
    return Material(
      color: statusColor.withOpacity(0.08),
      child: InkWell(
        onTap: onScrollToTop,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: statusColor.withOpacity(0.4), width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (statusIcon != null) ...[
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: stats.isEmpty
                    ? Text(
                        message ?? 'En attente de données…',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (var i = 0; i < stats.length; i++) ...[
                              _StatChip(stat: stats[i]),
                              if (i < stats.length - 1) ...[
                                const SizedBox(width: 10),
                                Container(
                                  width: 1,
                                  height: 18,
                                  color: statusColor.withOpacity(0.3),
                                ),
                                const SizedBox(width: 10),
                              ],
                            ],
                          ],
                        ),
                      ),
              ),
              if (clickable) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.expand_less_rounded,
                  color: statusColor.withOpacity(0.7),
                  size: 22,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.stat});
  final BannerStat stat;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${stat.label} ',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          stat.value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: stat.color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
