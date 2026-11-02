import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/logo.dart';
import 'illustrations.dart';

class _Page {
  const _Page(this.title, this.body);

  final String title;
  final String body;
}

const _pages = [
  _Page('See what you can make with the food you already have.',
      'MealLens turns a quick photo of your fridge into a list of ingredients and ideas for meals.'),
  _Page('Scan, then take a quick look.',
      'Keep ingredients visible and use even lighting. We show what we found, and you confirm or change anything.'),
  _Page('Cook with what you have.',
      'Recipes are sorted by how many of their ingredients you already have, with estimated nutrition information.'),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  bool get _last => _page == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() => _controller.nextPage(duration: motion(context, const Duration(milliseconds: 320)), curve: Curves.easeOutCubic);

  Future<void> _finish({required bool signUp}) async {
    await ref.read(settingsProvider.notifier).markOnboardingSeen();
    if (mounted) context.push(signUp ? '/sign-in?mode=sign-up' : '/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.sm, 0),
              child: Row(children: [
                const Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(fit: BoxFit.scaleDown, child: MealLensLogo(markSize: 28)),
                  ),
                ),
                const SizedBox(width: Space.sm),
                AnimatedOpacity(
                  opacity: _last ? 0 : 1,
                  duration: motion(context, const Duration(milliseconds: 200)),
                  child: TextButton(onPressed: _last ? null : () => _finish(signUp: false), child: const Text('Skip')),
                ),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _PageView(page: i, content: _pages[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.lg),
              child: Semantics(
                label: 'Page ${_page + 1} of ${_pages.length}',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _pages.length; i++)
                      AnimatedContainer(
                        duration: motion(context, const Duration(milliseconds: 220)),
                        margin: const EdgeInsets.symmetric(horizontal: Space.xs),
                        width: i == _page ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
              child: AnimatedSwitcher(
                duration: motion(context, const Duration(milliseconds: 220)),
                child: _last
                    ? Column(key: const ValueKey('final'), children: [
                        FilledButton(
                          onPressed: () => _finish(signUp: true),
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                          child: const Text('Create account'),
                        ),
                        const SizedBox(height: Space.md),
                        OutlinedButton(
                          onPressed: () => _finish(signUp: false),
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                          child: const Text('I already have an account'),
                        ),
                      ])
                    : FilledButton(
                        key: const ValueKey('next'),
                        onPressed: _next,
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        child: const Text('Next'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({required this.page, required this.content});

  final int page;
  final _Page content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, c) {
      final art = (c.maxHeight * 0.52).clamp(160.0, 340.0);
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: SizedBox.square(dimension: art, child: OnboardingIllustration(page: page))),
              const SizedBox(height: Space.xxl),
              Text(content.title, style: theme.textTheme.headlineLarge),
              const SizedBox(height: Space.md),
              Text(content.body, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    });
  }
}
