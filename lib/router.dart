import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/sign_in_screen.dart';
import 'features/fridge/fridge_screen.dart';
import 'features/home/home_shell.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/recipes/recipe_detail_screen.dart';
import 'features/recipes/recipes_screen.dart';
import 'features/scan/camera_screen.dart';
import 'features/scan/review_screen.dart';
import 'features/scan/scan_providers.dart';
import 'features/settings/settings_screen.dart';
import 'state/providers.dart';

/// Signed out: onboarding the first time, sign-in after that. Signed in: the fridge and recipes tabs.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);
  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: auth,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final public = location == '/onboarding' || location == '/sign-in';
      if (!auth.signedIn) {
        if (public) return null;
        return ref.read(settingsProvider).onboardingSeen ? '/sign-in' : '/onboarding';
      }
      if (public) return '/home';
      // The review screen needs its scan; if it is opened without one (e.g. after a restart), go home.
      if (location == '/scan/review' && state.extra is! ScanReviewArgs) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => SignInScreen(signUp: state.uri.queryParameters['mode'] == 'sign-up'),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (context, state) => const FridgeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/recipes', builder: (context, state) => const RecipesScreen())]),
        ],
      ),
      GoRoute(
        path: '/recipes/:id',
        builder: (context, state) => RecipeDetailScreen(recipeId: int.tryParse(state.pathParameters['id']!) ?? -1),
      ),
      GoRoute(path: '/scan', builder: (context, state) => const CameraScreen()),
      GoRoute(path: '/scan/review', builder: (context, state) => ReviewScreen(args: state.extra! as ScanReviewArgs)),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
