import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// Recipe card, in the order the guidelines ask for (§9): image, name, ingredient match,
/// missing count, key nutrition.
class RecipeCard extends StatelessWidget {
  const RecipeCard({super.key, required this.recipe, this.match, required this.onTap});

  final RecipeSummary recipe;
  final Recommendation? match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontFeatures: tabularFigures);
    final n = recipe.nutrition;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecipeThumbnail(recipe: recipe, size: 84),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.title, style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: Space.xs),
                    if (match != null) ...[
                      Text('${match!.matchPercent}% ingredient match',
                          style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
                      Text(missingText(match!), style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ] else
                      Text('${mealTypeLabel(recipe.mealType)} · ${recipe.totalMinutes} min', style: muted),
                    if (n != null) ...[
                      const SizedBox(height: Space.xs),
                      Text('${n.kcal.round()} kcal · ${n.proteinG.round()} g protein', style: muted),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String missingText(Recommendation r) {
  if (r.missingCount == 0) {
    return r.missingIngredients.isEmpty ? 'You have everything' : 'Only a garnish missing';
  }
  final names = r.missingIngredients.take(2).join(', ');
  return r.missingCount == 1 ? 'Missing 1 ingredient: $names' : 'Missing ${r.missingCount} ingredients';
}

/// Recipes have no photos yet, so a quiet tile with the meal type stands in.
class RecipeThumbnail extends StatelessWidget {
  const RecipeThumbnail({super.key, required this.recipe, this.size = 84, this.radius = Radii.thumbnail});

  final RecipeSummary recipe;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = recipe.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? Image.network(url, fit: BoxFit.cover, semanticLabel: recipe.title)
            : ColoredBox(
                color: scheme.surfaceContainer,
                child: Icon(mealTypeIcon(recipe.mealType), size: size * 0.38, color: scheme.onSurfaceVariant),
              ),
      ),
    );
  }
}
