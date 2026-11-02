import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/models.dart';
import '../theme/tokens.dart';

/// An inline message with an icon: errors and notices are never shown by colour alone (§11).
class InlineBanner extends StatelessWidget {
  const InlineBanner({super.key, required this.text, this.isError = false, this.icon});

  final String text;
  final bool isError;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = isError ? StatusColors.error : StatusColors.info;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(Radii.control)),
        child: Row(children: [
          Icon(icon ?? (isError ? Icons.error_outline_rounded : Icons.mark_email_unread_outlined), color: color, size: 20),
          const SizedBox(width: Space.md),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      ),
    );
  }
}

/// A status label: colour plus icon plus words (§4, §11).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.icon, required this.color});

  factory StatusPill.freshness(InventoryItem item) {
    final d = item.daysLeft;
    return switch (item.freshness) {
      Freshness.pastBest => const StatusPill(label: 'Past its best', icon: Icons.error_outline_rounded, color: StatusColors.error),
      Freshness.useSoon => StatusPill(
          label: d == 0 ? 'Use today' : 'Use within ${d == 1 ? '1 day' : '$d days'}',
          icon: Icons.schedule_rounded,
          color: StatusColors.attention,
        ),
      Freshness.fresh => const StatusPill(label: 'Fresh', icon: Icons.eco_outlined, color: StatusColors.success),
      Freshness.unknown => const StatusPill(label: 'No date', icon: Icons.remove_rounded, color: StatusColors.info),
    };
  }

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Color.lerp(color, Colors.white, 0.45)! : Color.lerp(color, Colors.black, 0.35)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm + 2, vertical: Space.xs),
      decoration: BoxDecoration(color: color.withValues(alpha: dark ? 0.22 : 0.14), borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: ink),
        const SizedBox(width: Space.xs),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: ink)),
      ]),
    );
  }
}

/// A calm empty state: an icon, one sentence of guidance and at most one action.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action, this.secondary});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xxl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainer, shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Space.xl),
          Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: Space.sm),
            Text(message!,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: Space.xl), action!],
          if (secondary != null) ...[const SizedBox(height: Space.sm), secondary!],
        ]),
      ),
    );
  }
}

/// A failed load, with a retry.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "We couldn't load this",
        message: errorText(error),
        action: OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      );
}

String errorText(Object e) => e is ApiException ? e.message : 'Something went wrong. Try again.';

void showMessage(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.screen, Space.xl, Space.screen, Space.sm),
        child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
      );
}

String titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Motion that respects the system's reduce-motion setting (§12).
Duration motion(BuildContext context, Duration d) => MediaQuery.of(context).disableAnimations ? Duration.zero : d;

String mealTypeLabel(String mealType) => titleCase(mealType);

IconData mealTypeIcon(String mealType) => switch (mealType) {
      'breakfast' => Icons.free_breakfast_outlined,
      'lunch' => Icons.lunch_dining_outlined,
      'dinner' => Icons.dinner_dining_outlined,
      'snack' => Icons.cookie_outlined,
      _ => Icons.restaurant_outlined,
    };

/// "2 pieces", "½ cup", "1 clove", "200 g": quantities as people say them.
String formatAmount(double quantity, String? unit) {
  final q = _quantity(quantity);
  if (unit == null || unit.isEmpty) return q;
  const plurals = {'piece': 'pieces', 'clove': 'cloves', 'slice': 'slices', 'cup': 'cups', 'pinch': 'pinches'};
  final plural = quantity > 1 ? plurals[unit] : null;
  return '$q ${plural ?? unit}';
}

String _quantity(double q) {
  if (q == q.roundToDouble()) return q.toInt().toString();
  const fractions = {'0.25': '¼', '0.33': '⅓', '0.50': '½', '0.66': '⅔', '0.67': '⅔', '0.75': '¾'};
  final whole = q.floor();
  final frac = fractions[(q - whole).toStringAsFixed(2)];
  if (frac != null) return whole == 0 ? frac : '$whole$frac';
  return q.toStringAsFixed(1);
}
