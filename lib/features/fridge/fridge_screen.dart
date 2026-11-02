import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/ingredient_picker.dart';
import '../../widgets/logo.dart';

class FridgeScreen extends ConsumerWidget {
  const FridgeScreen({super.key});

  Future<void> _addManually(BuildContext context, WidgetRef ref) async {
    final ing = await pickIngredient(context);
    if (ing == null || !context.mounted) return;
    try {
      await ref.read(inventoryProvider.notifier).add(ing.id);
      if (context.mounted) showMessage(context, '${ing.name} added to your fridge');
    } catch (e) {
      if (context.mounted) showMessage(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(inventoryProvider);
    final items = inventory.value ?? const <InventoryItem>[];
    return Scaffold(
      appBar: AppBar(
        title: const MealLensLogo(markSize: 28),
        actions: [
          IconButton(
            tooltip: 'Add manually',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => _addManually(context, ref),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: Space.xs),
        ],
      ),
      floatingActionButton: items.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/scan'),
              icon: const Icon(Icons.center_focus_weak_rounded),
              label: const Text('Scan ingredients'),
            ),
      body: switch (inventory) {
        AsyncData(:final value) when value.isEmpty => EmptyState(
            icon: Icons.kitchen_outlined,
            title: 'Your fridge is empty',
            message: 'Take a photo of a shelf or counter and we will list what we find.',
            action: FilledButton.icon(
              onPressed: () => context.push('/scan'),
              icon: const Icon(Icons.center_focus_weak_rounded),
              label: const Text('Scan ingredients'),
            ),
            secondary: TextButton(onPressed: () => _addManually(context, ref), child: const Text('Add an ingredient by hand')),
          ),
        AsyncData(:final value) => RefreshIndicator(
            onRefresh: () => ref.refresh(inventoryProvider.future),
            child: _FridgeList(items: value),
          ),
        AsyncError(:final error) => ErrorView(error: error, onRetry: () => ref.invalidate(inventoryProvider)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _FridgeList extends ConsumerWidget {
  const _FridgeList({required this.items});

  final List<InventoryItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final soon = items.where((i) => i.freshness == Freshness.useSoon || i.freshness == Freshness.pastBest).toList();
    final rest = items.where((i) => !soon.contains(i)).toList();
    final summary = '${items.length} ${items.length == 1 ? 'ingredient' : 'ingredients'}'
        '${soon.isEmpty ? '' : ' · ${soon.length} to use soon'}';
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your fridge', style: theme.textTheme.headlineLarge),
            const SizedBox(height: Space.xs),
            Text(summary, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
        if (soon.isNotEmpty) ...[
          const SectionHeader('Use soon'),
          for (final i in soon) _ItemTile(item: i),
        ],
        if (rest.isNotEmpty) ...[
          SectionHeader(soon.isEmpty ? 'Everything' : 'Everything else'),
          for (final i in rest) _ItemTile(item: i),
        ],
      ],
    );
  }
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({required this.item});

  final InventoryItem item;

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(inventoryProvider.notifier);
    try {
      await notifier.remove(item);
      if (context.mounted) {
        showMessage(context, '${item.ingredient.name} removed',
            action: SnackBarAction(label: 'Undo', onPressed: () => notifier.add(item.ingredient.id)));
      }
    } catch (e) {
      if (context.mounted) showMessage(context, errorText(e));
    }
  }

  Future<void> _setDate(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: item.expiresAt ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Best before',
    );
    if (picked == null) return;
    try {
      await ref.read(inventoryProvider.notifier).setExpiry(item, picked);
    } catch (e) {
      if (context.mounted) showMessage(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final date = item.expiresAt;
    final subtitle = [
      if (item.quantity != null) '${_qty(item.quantity!)} ${item.unit ?? ''}'.trim(),
      if (date != null) 'Best before ${DateFormat.MMMd().format(date)}',
      if (item.source == 'manual') 'Added by hand',
    ].join(' · ');
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.xl),
        color: StatusColors.error.withValues(alpha: 0.16),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.delete_outline_rounded, color: StatusColors.error),
          SizedBox(width: Space.sm),
          Text('Remove'),
        ]),
      ),
      onDismissed: (_) => _remove(context, ref),
      child: ListTile(
        minVerticalPadding: Space.md,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.screen),
        title: Text(item.ingredient.name, style: theme.textTheme.titleMedium),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          StatusPill.freshness(item),
          PopupMenuButton<String>(
            tooltip: 'More for ${item.ingredient.name}',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) => v == 'date' ? _setDate(context, ref) : _remove(context, ref),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'date', child: Text('Set best-before date')),
              PopupMenuItem(value: 'remove', child: Text('Remove')),
            ],
          ),
        ]),
        onTap: () => _setDate(context, ref),
      ),
    );
  }

  static String _qty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
}
