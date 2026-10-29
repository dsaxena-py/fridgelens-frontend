import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/sign_in_screen.dart';
import 'features/home/home_placeholder.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'state/providers.dart';

/// Signed out: onboarding the first time, sign-in after that. Signed in: home.
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
      return public ? '/home' : null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => SignInScreen(signUp: state.uri.queryParameters['mode'] == 'sign-up'),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomePlaceholder()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
