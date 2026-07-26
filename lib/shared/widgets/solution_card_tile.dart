import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/models/solution_card_model.dart';
import '../../l10n/app_localizations.dart';
import 'sdg_badge.dart';
import 'theme_icon_chip.dart';

/// Compact preview of a Solution Card for horizontal strips ("Latest
/// solutions" on the public dashboard).
class SolutionCardTile extends StatelessWidget {
  const SolutionCardTile({super.key, required this.card});

  final SolutionCardModel card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = categoryColor(card.theme);
    final intervention = card.primaryIntervention;

    return SizedBox(
      width: 240,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          onTap: () => context.go('/public/cluster/${card.clusterId}'),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              boxShadow: appCardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(kThemeIcons[card.theme], size: 14, color: color),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        (kThemeLabels[card.theme] ?? card.theme).toUpperCase(),
                        style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: color,
                            letterSpacing: 0.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  card.headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13, height: 1.3),
                ),
                const SizedBox(height: 8),
                if (intervention != null && intervention.costBand.isEstimated)
                  Text(
                    intervention.costBand.label,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.saffronDeep),
                  ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        card.routing.primary.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10.5, color: AppColors.inkFaint),
                      ),
                    ),
                    if (card.sdgGoals.isNotEmpty)
                      SdgBadge(goal: card.sdgGoals.first, size: 18),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.viewSolutionCard,
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.indigo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
