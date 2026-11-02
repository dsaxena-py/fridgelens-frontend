import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/ingredient_picker.dart';
import '../../widgets/scan.dart';
import 'scan_providers.dart';

/// The user's current answer for one detection. `action == null` means not answered yet.
class _Choice {
  _Choice(this.action);

  ReviewAction? action;
  IngredientRef? replacement;
}

/// Check what we found before anything reaches the fridge (§2 "In control", §9 ingredient status).
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.args});

  final ScanReviewArgs args;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late final Map<int, _Choice> _choices = {
    // Confident detections start confirmed; uncertain ones wait for a yes or no.
    for (final d in widget.args.scan.detections) d.id: _Choice(d.needsCheck ? null : ReviewAction.accept),
  };
  final List<Ingredient> _additions = [];
  bool _saving = false;
  String? _error;

  List<Detection> get _detections => widget.args.scan.detections;
  int get _unanswered => _choices.values.where((c) => c.action == null).length;

  int get _keptCount {
    final ids = <int>{
      for (final d in _detections)
        if (_choices[d.id]!.action == ReviewAction.accept)
          d.ingredient.id
        else if (_choices[d.id]!.action == ReviewAction.relabel)
          _choices[d.id]!.replacement!.id,
      for (final a in _additions) a.id,
    };
    return ids.length;
  }

  Future<void> _change(Detection d) async {
    final picked = await pickIngredient(context, title: 'What is this?');
    if (picked == null) return;
    setState(() {
      final c = _choices[d.id]!;
      if (picked.id == d.ingredient.id) {
        c
          ..action = ReviewAction.accept
          ..replacement = null;
      } else {
        c
          ..action = ReviewAction.relabel
          ..replacement = picked;
      }
    });
  }

  /// "No" on an uncertain item: it is either something else, or not an ingredient at all.
  Future<void> _notThis(Detection d) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.swap_horiz_rounded),
            title: const Text('It is a different ingredient'),
            onTap: () => Navigator.pop(context, 'change'),
          ),
          ListTile(
            leading: const Icon(Icons.remove_circle_outline_rounded),
            title: const Text("It isn't an ingredient"),
            onTap: () => Navigator.pop(context, 'remove'),
          ),
          const SizedBox(height: Space.md),
        ]),
      ),
    );
    if (choice == 'change') {
      await _change(d);
    } else if (choice == 'remove') {
      setState(() => _choices[d.id]!.action = ReviewAction.reject);
    }
  }

  Future<void> _addMissed() async {
    final picked = await pickIngredient(context, title: 'Add something we missed');
    if (picked != null && !_additions.any((a) => a.id == picked.id)) setState(() => _additions.add(picked));
  }

  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final decisions = [
        for (final d in _detections)
          DetectionDecision(d.id, _choices[d.id]!.action!, _choices[d.id]!.replacement?.id),
      ];
      final fridge = await ref.read(apiProvider).confirmScan(widget.args.scan.id, decisions, [for (final a in _additions) a.id]);
      ref.read(inventoryProvider.notifier).replace(fridge);
      if (!mounted) return;
      final n = _keptCount;
      showMessage(context, n == 0 ? 'Nothing was added to your fridge' : '$n ${n == 1 ? 'ingredient is' : 'ingredients are'} in your fridge');
      context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scan = widget.args.scan;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check ingredients'),
        leading: IconButton(tooltip: 'Close', icon: const Icon(Icons.close_rounded), onPressed: () => context.go('/home')),
      ),
      body: scan.failed
          ? EmptyState(
              icon: Icons.wb_sunny_outlined,
              title: "We couldn't process that image",
              message: 'Try again in brighter, even light.',
              action: FilledButton(onPressed: () => context.pushReplacement('/scan'), child: const Text('Retake photo')),
            )
          : _body(context),
      bottomNavigationBar: scan.failed ? null : _confirmBar(context),
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    final scan = widget.args.scan;
    final n = _detections.length;
    final aspect = (scan.imageWidth != null && scan.imageHeight != null && scan.imageHeight! > 0)
        ? scan.imageWidth! / scan.imageHeight!
        : 3 / 4;
    final ImageProvider image = scan.imageUrl != null ? NetworkImage(scan.imageUrl!) : FileImage(widget.args.photo);

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, Space.screen, Space.lg),
          child: Text(
            n == 0
                ? "We didn't spot any ingredients. Add them below, or retake the photo in brighter, even light."
                : 'We found $n ${n == 1 ? 'ingredient' : 'ingredients'}. Take a quick look before continuing.',
            style: theme.textTheme.bodyLarge,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.screen),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: Center(
              child: DetectionOverlay(
                image: image,
                aspectRatio: aspect,
                boxes: [
                  for (final d in _detections)
                    (box: d.box, label: _nameFor(d), state: _boxState(_choices[d.id]!)),
                ],
              ),
            ),
          ),
        ),
        if (n > 0) const SectionHeader('What we found'),
        for (final d in _detections) _DetectionRow(
          detection: d,
          choice: _choices[d.id]!,
          onAccept: () => setState(() => _choices[d.id]!
            ..action = ReviewAction.accept
            ..replacement = null),
          onRemove: () => setState(() => _choices[d.id]!
            ..action = ReviewAction.reject
            ..replacement = null),
          onUndo: () => setState(() => _choices[d.id]!
            ..action = d.needsCheck ? null : ReviewAction.accept
            ..replacement = null),
          onChange: () => _change(d),
          onNo: () => _notThis(d),
        ),
        const SectionHeader('Something missing?'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.screen),
          child: Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
            for (final a in _additions)
              InputChip(
                label: Text(a.name),
                onDeleted: () => setState(() => _additions.remove(a)),
                deleteButtonTooltipMessage: 'Remove ${a.name}',
              ),
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add an ingredient'),
              onPressed: _addMissed,
            ),
          ]),
        ),
      ],
    );
  }

  Widget _confirmBar(BuildContext context) {
    final theme = Theme.of(context);
    final waiting = _unanswered;
    final nothing = _detections.isEmpty && _additions.isEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, Space.md),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_error != null) ...[InlineBanner(text: _error!, isError: true), const SizedBox(height: Space.md)],
          if (waiting > 0) ...[
            Text('Answer ${waiting == 1 ? 'the question' : '$waiting questions'} above to continue.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: Space.sm),
          ],
          FilledButton(
            onPressed: waiting > 0 || nothing || _saving ? null : _confirm,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _saving
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Confirm inventory'),
          ),
        ]),
      ),
    );
  }

  String _nameFor(Detection d) => _choices[d.id]!.replacement?.name ?? d.ingredient.name;

  BoxState _boxState(_Choice c) => switch (c.action) {
        null => BoxState.needsCheck,
        ReviewAction.accept => BoxState.confirmed,
        ReviewAction.relabel => BoxState.changed,
        ReviewAction.reject => BoxState.removed,
      };
}

class _DetectionRow extends StatelessWidget {
  const _DetectionRow({
    required this.detection,
    required this.choice,
    required this.onAccept,
    required this.onRemove,
    required this.onUndo,
    required this.onChange,
    required this.onNo,
  });

  final Detection detection;
  final _Choice choice;
  final VoidCallback onAccept, onRemove, onUndo, onChange, onNo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = detection.ingredient.name;
    final muted = theme.colorScheme.onSurfaceVariant;

    final (IconData icon, Color color, String title, String subtitle) = switch (choice.action) {
      null => (Icons.help_outline_rounded, StatusColors.attention, _question(detection.ingredient), "We weren't sure about this one."),
      ReviewAction.accept => (Icons.check_circle_outline_rounded, StatusColors.success, name, 'Confirmed'),
      ReviewAction.relabel => (Icons.swap_horiz_rounded, StatusColors.info, choice.replacement!.name, 'Changed from ${name.toLowerCase()}'),
      ReviewAction.reject => (Icons.remove_circle_outline_rounded, muted, name, 'Removed'),
    };

    final removed = choice.action == ReviewAction.reject;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.screen - Space.lg),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title,
            style: theme.textTheme.titleMedium?.copyWith(
              decoration: removed ? TextDecoration.lineThrough : null,
              color: removed ? muted : null,
            )),
        subtitle: Text(subtitle),
        trailing: switch (choice.action) {
          null => Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton(onPressed: onAccept, child: const Text('Yes')),
              TextButton(onPressed: onNo, child: const Text('No')),
            ]),
          ReviewAction.reject || ReviewAction.relabel => TextButton(onPressed: onUndo, child: const Text('Undo')),
          ReviewAction.accept => Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: 'Change $name', icon: const Icon(Icons.edit_outlined), onPressed: onChange),
              IconButton(tooltip: 'Remove $name', icon: const Icon(Icons.close_rounded), onPressed: onRemove),
            ]),
        },
      ),
    );
  }

  /// Ingredients named as a mass or a plural read without an article: "Is this milk?",
  /// "Is this a bell pepper?".
  static const _noArticle = {
    'garlic', 'broccoli', 'cauliflower', 'leafy_greens', 'strawberry', 'mushroom',
    'milk', 'cheese', 'yogurt', 'butter', 'chicken', 'bread',
  };

  static String _question(IngredientRef i) {
    final name = i.name.toLowerCase();
    if (_noArticle.contains(i.slug)) return 'Is this $name?';
    return 'Is this ${'aeiou'.contains(name[0]) ? 'an' : 'a'} $name?';
  }
}
