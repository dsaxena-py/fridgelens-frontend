import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/auth.dart';
import 'features/splash/splash_screen.dart';
import 'router.dart';
import 'state/providers.dart';
import 'theme/theme.dart';
import 'theme/tokens.dart';

/// What the app needs before its first real screen.
class Startup {
  const Startup({required this.prefs, required this.auth});

  final SharedPreferences prefs;
  final AuthService auth;
}

Future<Startup> defaultStartup() async {
  if (!Env.configured) throw const MissingConfig();
  final prefs = await SharedPreferences.getInstance();
  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseKey);
  return Startup(prefs: prefs, auth: SupabaseAuthService(Supabase.instance.client.auth));
}

class MissingConfig implements Exception {
  const MissingConfig();
}

/// Shows the splash screen while start-up runs, then the app. The splash stays at least long
/// enough for the wordmark to fade in, unless the system asks for reduced motion.
class MealLensRoot extends StatefulWidget {
  const MealLensRoot({
    super.key,
    this.startup = defaultStartup,
    this.minimumSplash = const Duration(milliseconds: 900),
    this.overrides = const [],
  });

  final Future<Startup> Function() startup;
  final Duration minimumSplash;

  /// Extra provider overrides; tests use them to swap in a fake backend and camera.
  final List<Override> overrides;

  @override
  State<MealLensRoot> createState() => _MealLensRootState();
}

class _MealLensRootState extends State<MealLensRoot> {
  Startup? _ready;
  Object? _error;
  bool _slow = false;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _slow = false;
    });
    _slowTimer = Timer(const Duration(seconds: 2), () => mounted ? setState(() => _slow = true) : null);
    final reduceMotion = PlatformDispatcher.instance.accessibilityFeatures.disableAnimations;
    try {
      final results = await Future.wait([
        widget.startup(),
        Future<void>.delayed(reduceMotion ? Duration.zero : widget.minimumSplash),
      ]);
      if (mounted) setState(() => _ready = results.first as Startup);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      _slowTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _ready;
    if (ready == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: _error == null ? SplashScreen(slow: _slow) : _StartupError(error: _error!, onRetry: _start),
      );
    }
    return ProviderScope(
      retry: (_, _) => null, // show errors to the user rather than retrying silently
      overrides: [
        sharedPreferencesProvider.overrideWithValue(ready.prefs),
        authProvider.overrideWithValue(ready.auth),
        ...widget.overrides,
      ],
      child: const MealLensApp(),
    );
  }
}

class MealLensApp extends ConsumerWidget {
  const MealLensApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp.router(
      title: 'MealLens',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missing = error is MissingConfig;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(missing ? 'MealLens needs its settings' : "MealLens couldn't start", style: theme.textTheme.headlineMedium),
              const SizedBox(height: Space.md),
              Text(
                missing
                    ? 'Run the app with: flutter run --dart-define-from-file=config.json (see config.example.json).'
                    : 'Check your internet connection and try again.',
                style: theme.textTheme.bodyLarge,
              ),
              if (!missing) ...[
                const SizedBox(height: Space.xl),
                FilledButton(onPressed: onRetry, child: const Text('Try again')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
