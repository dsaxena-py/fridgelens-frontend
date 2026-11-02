// Renders each screen of this step, light and dark, with the real fonts, for design review.
// Run: flutter test tool/screenshots_test.dart --update-goldens   (writes tool/screenshots/*.png)
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meallens/features/splash/splash_screen.dart';
import 'package:meallens/theme/theme.dart';

import 'package:meallens/data/models.dart';
import 'package:meallens/features/scan/review_screen.dart';
import 'package:meallens/features/scan/scan_providers.dart';
import 'package:meallens/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../test/fakes.dart';
import '../test/helpers.dart';

Future<void> _loadFonts() async {
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  final icons = File('$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync();
  await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons)))).load();
  for (final (family, file) in [('NunitoSans_regular', 'Regular'), ('NunitoSans_500', 'Medium')]) {
    final bytes = File('assets/google_fonts/NunitoSans-$file.ttf').readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  await expectLater(find.byType(MaterialApp).first, matchesGoldenFile('screenshots/$name.png'));
}

void main() {
  setUpAll(_loadFonts);

  for (final b in Brightness.values) {
    final mode = b.name;
    testWidgets('splash $mode', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.platformBrightnessTestValue = b;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(b), home: const SplashScreen()));
      await _shot(tester, '01_splash_$mode');
    });

    testWidgets('onboarding and sign in $mode', (tester) async {
      await pumpApp(tester, brightness: b);
      await _shot(tester, '02_onboarding_1_$mode');
      await tester.tap(find.text('Next'));
      await _shot(tester, '03_onboarding_2_$mode');
      await tester.tap(find.text('Next'));
      await _shot(tester, '04_onboarding_3_$mode');
      await tester.tap(find.text('I already have an account'));
      await _shot(tester, '05_sign_in_$mode');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'cook@example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'wrong');
      await tester.tap(find.byType(FilledButton));
      await _shot(tester, '06_sign_in_error_$mode');
      await tester.tap(find.text('Create an account instead'));
      await _shot(tester, '07_create_account_$mode');
    });
  }

  for (final b in Brightness.values) {
    final mode = b.name;

    testWidgets('fridge $mode', (tester) async {
      final auth = FakeAuth();
      await auth.signIn('cook@example.com', 'correct-horse');
      await pumpApp(tester, brightness: b, prefs: {'onboarding_seen': true}, auth: auth);
      await _shot(tester, '10_fridge_empty_$mode');
    });

    testWidgets('fridge with items $mode', (tester) async {
      final auth = FakeAuth();
      await auth.signIn('cook@example.com', 'correct-horse');
      final api = FakeApi()
        ..stock('leafy_greens', daysLeft: 1)
        ..stock('milk', daysLeft: -1)
        ..stock('egg', daysLeft: 30)
        ..stock('tomato', daysLeft: 6)
        ..stock('bell_pepper');
      await pumpApp(tester, brightness: b, prefs: {'onboarding_seen': true}, auth: auth, api: api, overrides: [
        camerasProvider.overrideWith((ref) async => []),
      ]);
      await _shot(tester, '11_fridge_$mode');
      await tester.tap(find.text('Scan ingredients'));
      await _shot(tester, '12_camera_no_camera_$mode');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await _shot(tester, '15_settings_$mode');
    });

    testWidgets('review $mode', (tester) async {
      final photo = File('tool/fixtures/fridge.jpg');
      final egg = catalog[0], tomato = catalog[1], greens = catalog[5], milk = catalog[4];
      final scan = Scan(id: 's', status: 'awaiting_review', imageWidth: 900, imageHeight: 1200, detections: [
        Detection(id: 1, ingredient: IngredientRef(id: milk.id, slug: milk.slug, name: milk.name), confidence: 0.91, box: const Box(0.09, 0.12, 0.3, 0.35), needsCheck: false),
        Detection(id: 2, ingredient: IngredientRef(id: tomato.id, slug: tomato.slug, name: tomato.name), confidence: 0.86, box: const Box(0.39, 0.24, 0.64, 0.35), needsCheck: false),
        Detection(id: 3, ingredient: IngredientRef(id: egg.id, slug: egg.slug, name: egg.name), confidence: 0.88, box: const Box(0.12, 0.64, 0.6, 0.72), needsCheck: false),
        Detection(id: 4, ingredient: IngredientRef(id: greens.id, slug: greens.slug, name: greens.name), confidence: 0.41, box: const Box(0.61, 0.52, 0.92, 0.73), needsCheck: true),
      ]);
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.platformBrightnessTestValue = b;
      addTearDown(tester.view.reset);
      // Decode the photo for real, outside the fake clock and before the screen asks for it,
      // so the screen finds it in the image cache instead of starting a load on the fake clock.
      await tester.runAsync(() async {
        final done = Completer<void>();
        FileImage(photo).resolve(ImageConfiguration.empty).addListener(ImageStreamListener(
              (_, _) => done.isCompleted ? null : done.complete(),
              onError: (e, _) => done.isCompleted ? null : done.completeError(e),
            ));
        await done.future.timeout(const Duration(seconds: 20));
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [apiProvider.overrideWithValue(FakeApi(scanResult: scan))],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(b),
          home: ReviewScreen(args: ScanReviewArgs(scan: scan, photo: photo)),
        ),
      ));
      await tester.pump();
      await _shot(tester, '13_review_$mode');
      await tester.scrollUntilVisible(find.text('Is this leafy greens?'), 200);
      await _shot(tester, '14_review_question_$mode');
    });
  }
}
