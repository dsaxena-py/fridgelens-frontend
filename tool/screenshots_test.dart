// Renders each screen of this step, light and dark, with the real fonts, for design review.
// Run: flutter test tool/screenshots_test.dart --update-goldens   (writes tool/screenshots/*.png)
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meallens/features/splash/splash_screen.dart';
import 'package:meallens/theme/theme.dart';

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
}
