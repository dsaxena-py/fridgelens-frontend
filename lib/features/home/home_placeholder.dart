import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../../widgets/logo.dart';

/// Where signed-in people land until the fridge screen is built in the next step.
class HomePlaceholder extends ConsumerWidget {
  const HomePlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(title: const MealLensLogo(markSize: 28)),
      body: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("You're signed in", style: theme.textTheme.headlineLarge),
            const SizedBox(height: Space.sm),
            Text(auth.email ?? '', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: Space.xl),
            Text('Your fridge will appear here.', style: theme.textTheme.bodyLarge),
            const Spacer(),
            OutlinedButton(
              onPressed: auth.signOut,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
