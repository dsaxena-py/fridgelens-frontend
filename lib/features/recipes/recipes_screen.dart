import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/recipe_card.dart';

/// Recipes: matches for the fridge first, then browsing and saved recipes.
class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Recipes'),
            actions: [
              IconButton(tooltip: 'Settings', icon: const Icon(Icons.tune_rounded), onPressed: () => context.push('/settings')),
              const SizedBox(width: Space.xs),
            ],
            bottom: TabBar(
              tabAlignment: TabAlignment.start,
              isScrollable: true,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: Theme.of(context).textTheme.labelLarge,
              tabs: const [Tab(text: 'For your fridge'), Tab(text: 'Browse'), Tab(text: 'Saved')],
            ),
          ),
          body: const TabBarView(children: [_ForYourFridge(), _Browse(), _Saved()]),
        ),
      );
}

void _openRecipe(BuildContext context, int id) => context.push('/recipes/$id');

class _ForYourFridge extends ConsumerWidget {
  const _ForYourFridge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return switch (ref.watch(recommendationsProvider)) {
      AsyncData(:final value) when value.inventoryCount == 0 => EmptyState(
          icon: Icons.kitchen_outlined,
          title: 'Add a few ingredients first',
          message: 'Recipes are matched to what is in your fridge.',
          action: FilledButton.icon(
            onPressed: () => context.push('/scan'),
            icon: const Icon(Icons.center_focus_weak_rounded),
            label: const Text('Scan ingredients'),
          ),
        ),
      AsyncData(:final value) when value.items.isEmpty => EmptyState(
          icon: Icons.search_rounded,
          title: 'No close matches yet',
          message: 'Add another ingredient or browse recipes with one or two extras.',
          action: OutlinedButton(onPressed: () => DefaultTabController.of(context).animateTo(1), child: const Text('Browse recipes')),
        ),
      AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(recommendationsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, Space.xxl),
            itemCount: value.items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: Space.md),
            itemBuilder: (context, i) => i == 0
                ? Text(
                    'Sorted by how many of their ingredients you already have.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  )
                : RecipeCard(
                    recipe: value.items[i - 1].recipe,
                    match: value.items[i - 1],
                    onTap: () => _openRecipe(context, value.items[i - 1].recipe.id),
                  ),
          ),
        ),
      AsyncError(:final error) => ErrorView(error: error, onRetry: () => ref.invalidate(recommendationsProvider)),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

class _Browse extends ConsumerStatefulWidget {
  const _Browse();

  @override
  ConsumerState<_Browse> createState() => _BrowseState();
}

class _BrowseState extends ConsumerState<_Browse> {
  late final _search = TextEditingController(text: ref.read(browseQueryProvider).query);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => ref.read(browseQueryProvider.notifier).setQuery(q));
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(browseQueryProvider);
    final results = ref.watch(browseRecipesProvider);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, Space.sm),
        child: TextField(
          controller: _search,
          onChanged: _onSearch,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(hintText: 'Search recipes or ingredients', prefixIcon: Icon(Icons.search_rounded)),
        ),
      ),
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Space.screen),
          children: [
            for (final type in [null, ..._mealTypes])
              Padding(
                padding: const EdgeInsets.only(right: Space.sm),
                child: ChoiceChip(
                  label: Text(type == null ? 'All' : mealTypeLabel(type)),
                  selected: query.mealType == type,
                  showCheckmark: false,
                  onSelected: (_) => ref.read(browseQueryProvider.notifier).setMealType(type),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: switch (results) {
          AsyncData(:final value) when value.isEmpty => const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No recipes found',
              message: 'Try a different word, or another meal type.',
            ),
          AsyncData(:final value) => ListView.separated(
              padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, Space.screen, Space.xxl),
              itemCount: value.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.md),
              itemBuilder: (context, i) => RecipeCard(recipe: value[i], onTap: () => _openRecipe(context, value[i].id)),
            ),
          AsyncError(:final error) => ErrorView(error: error, onRetry: () => ref.invalidate(browseRecipesProvider)),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    ]);
  }
}

class _Saved extends ConsumerWidget {
  const _Saved();

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(savedRecipesProvider)) {
        AsyncData(:final value) when value.isEmpty => const EmptyState(
            icon: Icons.bookmark_outline_rounded,
            title: 'Nothing saved yet',
            message: 'Tap the bookmark on a recipe to keep it here.',
          ),
        AsyncData(:final value) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, Space.xxl),
            itemCount: value.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.md),
            itemBuilder: (context, i) => RecipeCard(recipe: value[i], onTap: () => _openRecipe(context, value[i].id)),
          ),
        AsyncError(:final error) => ErrorView(error: error, onRetry: () => ref.invalidate(savedRecipesProvider)),
        _ => const Center(child: CircularProgressIndicator()),
      };
}
