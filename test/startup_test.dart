import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meallens/app.dart';
import 'package:meallens/features/splash/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('splash shows the brand while starting, then the first screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final done = Completer<Startup>();
    await tester.pumpWidget(MealLensRoot(startup: () => done.future, minimumSplash: Duration.zero));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('MealLens'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.pump(const Duration(seconds: 2)); // slow start-up: a quiet progress line appears
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    done.complete(Startup(prefs: prefs, auth: FakeAuth()));
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('See what you can make with the food you already have.'), findsOneWidget);
  });

  testWidgets('a start-up failure offers a retry', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var attempts = 0;
    await tester.pumpWidget(MealLensRoot(
      minimumSplash: Duration.zero,
      startup: () async {
        if (attempts++ == 0) throw Exception('offline');
        return Startup(prefs: prefs, auth: FakeAuth());
      },
    ));
    await tester.pumpAndSettle();
    expect(find.text("MealLens couldn't start"), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('See what you can make with the food you already have.'), findsOneWidget);
  });

  testWidgets('missing build settings explain how to run the app', (tester) async {
    await tester.pumpWidget(MealLensRoot(minimumSplash: Duration.zero, startup: () async => throw const MissingConfig()));
    await tester.pumpAndSettle();
    expect(find.text('MealLens needs its settings'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });
}
