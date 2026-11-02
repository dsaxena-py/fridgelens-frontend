import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/recipe_card.dart';

class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});

  final int recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(recipeDetailProvider(recipeId))) {
        AsyncData(:final value) => _Detail(detail: value),
        AsyncError(:final error) => Scaffold(
            appBar: AppBar(),
            body: ErrorView(error: error, onRetry: () => ref.invalidate(recipeDetailProvider(recipeId))),
          ),
        _ => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      };
}

class _Detail extends ConsumerStatefulWidget {
  const _Detail({required this.detail});

  final RecipeDetail detail;

  @override
  ConsumerState<_Detail> createState() => _DetailState();
}

class _DetailState extends ConsumerState<_Detail> {
  late bool _saved = widget.detail.saved;

  RecipeSummary get _recipe => widget.detail.summary;

  Future<void> _toggleSaved() async {
    final next = !_saved;
    setState(() => _saved = next);
    try {
      await ref.read(apiProvider).setSaved(_recipe.id, next);
      ref.invalidate(savedRecipesProvider);
      if (mounted) showMessage(context, next ? 'Saved to your recipes' : 'Removed from saved recipes');
    } catch (e) {
      if (mounted) {
        setState(() => _saved = !next);
        showMessage(context, errorText(e));
      }
    }
  }

  Future<void> _cooked() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CookedSheet(recipe: _recipe),
    );
    if (result != null && mounted) showMessage(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.detail;
    final r = _recipe;
    final coverage = d.coverage;
    final missing = [for (final i in d.ingredients) if (!i.isPantryStaple && !i.inFridge) i.ingredient.name];

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: _saved ? 'Saved' : 'Save recipe',
            isSelected: _saved,
            icon: const Icon(Icons.bookmark_outline_rounded),
            selectedIcon: const Icon(Icons.bookmark_rounded),
            onPressed: _toggleSaved,
          ),
          const SizedBox(width: Space.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.xxl),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.screen),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RecipeThumbnail(recipe: r, size: 72, radius: Radii.card),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.title, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: Space.xs),
                  Text(
                    [mealTypeLabel(r.mealType), '${r.totalMinutes} min', '${r.servings} ${r.servings == 1 ? 'serving' : 'servings'}', titleCase(r.difficulty)].join(' · '),
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ]),
              ),
            ]),
          ),
          if (r.description != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, Space.lg, Space.screen, 0),
              child: Text(r.description!, style: theme.textTheme.bodyLarge),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.screen, Space.xl, Space.screen, 0),
            child: _MatchCard(have: coverage.have, total: coverage.total, missing: missing),
          ),
          if (r.nutrition != null) ...[
            const SectionHeader('Nutrition per serving'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.screen),
              child: _NutritionTable(n: r.nutrition!),
            ),
          ],
          const SectionHeader('Ingredients'),
          for (final i in d.ingredients) _IngredientRow(item: i),
          const SectionHeader('Steps'),
          for (final (n, step) in d.steps.indexed) _StepRow(number: n + 1, text: step),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, Space.screen, Space.md),
          child: FilledButton.icon(
            onPressed: _cooked,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: const Icon(Icons.restaurant_rounded),
            label: const Text('I cooked this'),
          ),
        ),
      ),
    );
  }
}

/// One circular indicator for the ingredient match, always with the numbers written out (§9).
class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.have, required this.total, required this.missing});

  final int have, total;
  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final everything = total > 0 && have == total;
    final message = total == 0
        ? 'Only pantry staples needed.'
        : everything
            ? 'You have everything for this recipe.'
            : 'You already have $have of the $total ingredients.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Row(children: [
          SizedBox.square(
            dimension: 64,
            child: CustomPaint(
              painter: _RingPainter(
                value: total == 0 ? 1 : have / total,
                track: theme.colorScheme.surfaceContainerHighest,
                color: theme.colorScheme.primary,
              ),
              child: Center(
                child: Text('$have/$total',
                    style: theme.textTheme.labelLarge?.copyWith(fontFeatures: tabularFigures), semanticsLabel: ''),
              ),
            ),
          ),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(message, style: theme.textTheme.titleMedium),
              if (missing.isNotEmpty) ...[
                const SizedBox(height: Space.xs),
                Text('Missing: ${missing.join(', ')}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.track, required this.color});

  final double value;
  final Color track, color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(rect, 0, math.pi * 2, false, Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke);
    if (value > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value.clamp(0, 1), false, Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color || old.track != track;
}

class _NutritionTable extends StatelessWidget {
  const _NutritionTable({required this.n});

  final Nutrition n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = [
      ('Energy', '${n.kcal.round()} kcal'),
      ('Protein', '${n.proteinG.toStringAsFixed(1)} g'),
      ('Carbohydrates', '${n.carbsG.toStringAsFixed(1)} g'),
      ('Fat', '${n.fatG.toStringAsFixed(1)} g'),
      ('Fiber', '${n.fiberG.toStringAsFixed(1)} g'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
          child: Column(children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xs + 2),
                child: Row(children: [
                  Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
                  Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontFeatures: tabularFigures)),
                ]),
              ),
          ]),
        ),
      ),
      const SizedBox(height: Space.sm),
      Text('Estimated nutrition information from USDA data, not medical advice.',
          style: theme.textTheme.bodySmall),
    ]);
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.item});

  final RecipeIngredient item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final (IconData icon, Color color, String status) = item.inFridge
        ? (Icons.check_circle_outline_rounded, StatusColors.success, 'In your fridge')
        : item.isPantryStaple
            ? (Icons.inventory_2_outlined, muted, 'Pantry staple')
            : (Icons.add_shopping_cart_rounded, StatusColors.attention, 'Missing');
    final amount = formatAmount(item.quantity, item.unit);
    final role = item.role == 'core' ? null : (item.role == 'garnish' ? 'garnish' : 'optional extra');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.screen, vertical: Space.sm),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 20, color: color, semanticLabel: status)),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.ingredient.name, style: theme.textTheme.bodyLarge),
            Text(
              [amount, ?role, ?item.note, if (!item.inFridge) status].join(' · '),
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ]),
        ),
      ]),
    );
  }

}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.screen, vertical: Space.sm),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainer, shape: BoxShape.circle),
          child: Text('$number', style: theme.textTheme.labelMedium),
        ),
        const SizedBox(width: Space.md),
        Expanded(child: Padding(padding: const EdgeInsets.only(top: 3), child: Text(text, style: theme.textTheme.bodyLarge))),
      ]),
    );
  }
}

/// "I cooked this": an optional rating and, if wanted, taking the main ingredients out of the fridge.
class _CookedSheet extends ConsumerStatefulWidget {
  const _CookedSheet({required this.recipe});

  final RecipeSummary recipe;

  @override
  ConsumerState<_CookedSheet> createState() => _CookedSheetState();
}

class _CookedSheetState extends ConsumerState<_CookedSheet> {
  int? _rating;
  bool _removeUsed = true;
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref.read(apiProvider).cooked(widget.recipe.id, rating: _rating, removeUsed: _removeUsed);
      if (_removeUsed) await ref.read(inventoryProvider.notifier).reload();
      if (!mounted) return;
      final names = [for (final i in result.removed) i.name.toLowerCase()];
      Navigator.of(context).pop(names.isEmpty
          ? 'Enjoy your meal'
          : 'Enjoy your meal. We took ${_list(names)} out of your fridge.');
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = errorText(e);
        });
      }
    }
  }

  static String _list(List<String> names) =>
      names.length == 1 ? names.first : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.lg),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('How was it?', style: theme.textTheme.titleLarge),
          const SizedBox(height: Space.xs),
          Text('A rating is optional.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: Space.md),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                tooltip: '$i of 5',
                isSelected: (_rating ?? 0) >= i,
                icon: const Icon(Icons.star_outline_rounded),
                selectedIcon: const Icon(Icons.star_rounded, color: StatusColors.attention),
                onPressed: () => setState(() => _rating = _rating == i ? null : i),
              ),
          ]),
          const SizedBox(height: Space.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _removeUsed,
            onChanged: (v) => setState(() => _removeUsed = v),
            title: const Text('Take the main ingredients out of my fridge'),
          ),
          if (_error != null) ...[const SizedBox(height: Space.sm), InlineBanner(text: _error!, isError: true)],
          const SizedBox(height: Space.md),
          FilledButton(
            onPressed: _saving ? null : _submit,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _saving
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Done'),
          ),
        ]),
      ),
    );
  }
}
