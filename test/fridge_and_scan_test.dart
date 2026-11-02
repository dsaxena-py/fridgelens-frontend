import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meallens/data/api.dart';
import 'package:meallens/data/models.dart';
import 'package:meallens/features/scan/scan_providers.dart';
import 'package:meallens/features/settings/settings_screen.dart';

import 'fakes.dart';
import 'helpers.dart';

const signedIn = {'onboarding_seen': true};

Scan scanOf(List<Detection> detections, {String status = 'awaiting_review'}) =>
    Scan(id: 'scan-1', status: status, imageWidth: 300, imageHeight: 400, detections: detections);

Future<FakeAuth> _signedInAuth() async {
  final auth = FakeAuth();
  await auth.signIn('cook@example.com', 'correct-horse');
  return auth;
}

/// Opens the camera screen on a device without a camera, picks [photo] from the gallery and
/// waits for the review screen.
Future<void> _scanFromGallery(WidgetTester tester) async {
  await tester.tap(find.text('Scan ingredients').first);
  await tester.pumpAndSettle();
  expect(find.textContaining('No camera is available here'), findsOneWidget);
  await tester.tap(find.byTooltip('Gallery'));
  await tester.pumpAndSettle();
}

void main() {
  late File photo;
  setUpAll(() => photo = testPhoto());

  final noCamera = [
    camerasProvider.overrideWith((ref) async => []),
    pickPhotoProvider.overrideWithValue(() async => photo),
  ];

  group('fridge', () {
    testWidgets('empty fridge offers a scan and adding by hand', (tester) async {
      final app = await pumpApp(tester, prefs: signedIn, auth: await _signedInAuth());
      expect(find.text('Your fridge is empty'), findsOneWidget);
      expect(find.text('Scan ingredients'), findsOneWidget);

      await tester.tap(find.text('Add an ingredient by hand'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'mil');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Milk'));
      await tester.pumpAndSettle();

      expect(find.text('Milk added to your fridge'), findsOneWidget);
      expect(find.text('Your fridge'), findsOneWidget);
      expect(app.api.fridge.single.ingredient.slug, 'milk');
    });

    testWidgets('lists items to use soon first, with labelled freshness', (tester) async {
      final api = FakeApi()
        ..stock('egg', daysLeft: 20)
        ..stock('leafy_greens', daysLeft: 1)
        ..stock('milk', daysLeft: -1);
      await pumpApp(tester, prefs: signedIn, auth: await _signedInAuth(), api: api);

      expect(find.text('3 ingredients · 2 to use soon'), findsOneWidget);
      expect(find.text('Use soon'), findsOneWidget);
      expect(find.text('Use within 1 day'), findsOneWidget);
      expect(find.text('Past its best'), findsOneWidget);
      expect(find.text('Fresh'), findsOneWidget);
      final useSoonTop = tester.getTopLeft(find.text('Leafy greens')).dy;
      expect(useSoonTop, lessThan(tester.getTopLeft(find.text('Egg')).dy));
    });

    testWidgets('removing an item can be undone', (tester) async {
      final api = FakeApi()..stock('egg', daysLeft: 20);
      await pumpApp(tester, prefs: signedIn, auth: await _signedInAuth(), api: api);
      await tester.tap(find.byTooltip('More for Egg'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Egg removed'), findsOneWidget);
      expect(api.fridge, isEmpty);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(api.fridge.single.ingredient.slug, 'egg');
    });
  });

  group('scan and review', () {
    final egg = catalog[0], tomato = catalog[1], onion = catalog[2];

    testWidgets('check, correct and confirm what was found', (tester) async {
      final api = FakeApi(scanResult: scanOf([detection(11, egg, 0.92, 0.05), detection(12, tomato, 0.88, 0.35), detection(13, onion, 0.42, 0.65)]));
      await pumpApp(tester, prefs: signedIn, auth: await _signedInAuth(), api: api, overrides: noCamera);
      await _scanFromGallery(tester);

      expect(find.text('We found 3 ingredients. Take a quick look before continuing.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Is this an onion?'), 200);
      expect(find.text('Is this an onion?'), findsOneWidget);
      expect(find.text('Answer the question above to continue.'), findsOneWidget);
      FilledButton confirmButton() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm inventory'));
      expect(confirmButton().onPressed, isNull);

      // The onion is not an ingredient.
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("It isn't an ingredient"));
      await tester.pumpAndSettle();
      expect(find.text('Removed'), findsOneWidget);

      // The tomato is really a bell pepper.
      await tester.scrollUntilVisible(find.byTooltip('Change Tomato'), -100);
      await tester.tap(find.byTooltip('Change Tomato'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'pepper');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bell pepper'));
      await tester.pumpAndSettle();
      expect(find.text('Changed from tomato'), findsOneWidget);

      // Milk was missed.
      await tester.scrollUntilVisible(find.text('Add an ingredient'), 200);
      await tester.tap(find.text('Add an ingredient'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'milk');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Milk'));
      await tester.pumpAndSettle();

      expect(confirmButton().onPressed, isNotNull);
      await tester.tap(find.text('Confirm inventory'));
      await tester.pumpAndSettle();

      final sent = api.confirmed.single;
      expect([for (final d in sent.decisions) (d.detectionId, d.action, d.ingredientId)], [
        (11, ReviewAction.accept, null),
        (12, ReviewAction.relabel, 4),
        (13, ReviewAction.reject, null),
      ]);
      expect(sent.additions, [5]);
      expect(find.text('3 ingredients are in your fridge'), findsOneWidget);
      expect(find.text('Your fridge'), findsOneWidget);
      for (final name in ['Egg', 'Bell pepper', 'Milk']) {
        expect(find.text(name), findsOneWidget);
      }
    });

    testWidgets('saying yes to an uncertain item confirms it', (tester) async {
      final api = FakeApi(scanResult: scanOf([detection(13, onion, 0.42, 0.4)]));
      await pumpApp(tester, prefs: signedIn, auth: await _signedInAuth(), api: api, overrides: noCamera);
      await _scanFromGallery(tester);
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmed'), findsOneWidget);
      await tester.tap(find.text('Confirm inventory'));
      await tester.pumpAndSettle();
      expect(api.confirmed.single.decisions.single.action, ReviewAction.accept);
    });

    testWidgets('nothing found: confirm waits for a manual addition', (tester) async {
      final api = FakeApi(scanResult: scanOf([]));
      await pumpApp(tester, prefs: signedIn, auth: await _signedInAuth(), api: api, overrides: noCamera);
      await _scanFromGallery(tester);
      expect(find.textContaining("We didn't spot any ingredients"), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm inventory')).onPressed, isNull);
    });

    testWidgets('a scan the server could not process offers a retake', (tester) async {
      final api = FakeApi(scanResult: scanOf([], status: 'failed'));
      await pumpApp(tester, prefs: signedIn, auth: await _signedInAuth(), api: api, overrides: noCamera);
      await _scanFromGallery(tester);
      expect(find.text("We couldn't process that image"), findsOneWidget);
      expect(find.text('Try again in brighter, even light.'), findsOneWidget);
      await tester.tap(find.text('Retake photo'));
      await tester.pumpAndSettle();
      expect(find.text('Scan ingredients'), findsOneWidget);
    });

    testWidgets('an upload error stays on the camera with a clear message', (tester) async {
      final api = FakeApi()..uploadError = ApiException("We couldn't reach MealLens. Check the server address in Settings.");
      await pumpApp(tester, prefs: signedIn, auth: await _signedInAuth(), api: api, overrides: noCamera);
      await _scanFromGallery(tester);
      expect(find.text("We couldn't reach MealLens. Check the server address in Settings."), findsOneWidget);
      expect(find.byTooltip('Gallery'), findsOneWidget);
    });

    testWidgets('review fits a small phone with large text', (tester) async {
      final api = FakeApi(scanResult: scanOf([detection(11, egg, 0.92, 0.05), detection(13, onion, 0.42, 0.65)]));
      await pumpApp(tester,
          prefs: signedIn, auth: await _signedInAuth(), api: api, overrides: noCamera, size: const Size(320, 568), textScale: 1.6);
      await tester.tap(find.text('Scan ingredients').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Gallery'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm inventory'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('settings', () {
    testWidgets('validates, saves and tests the server address', (tester) async {
      final checked = <String>[];
      final app = await pumpApp(tester, prefs: signedIn, auth: await _signedInAuth(), overrides: [
        serverCheckProvider.overrideWithValue((url) async {
          checked.add(url);
          return 'fake';
        }),
      ]);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '192.168.1.20:8000');
      await tester.tap(find.text('Save and test connection'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Start the address with http://'), findsOneWidget);
      expect(checked, isEmpty);

      await tester.enterText(find.byType(TextField), 'http://192.168.1.20:8000/');
      await tester.tap(find.text('Save and test connection'));
      await tester.pumpAndSettle();
      expect(checked, ['http://192.168.1.20:8000/']);
      expect(app.prefs.getString('api_base_url'), 'http://192.168.1.20:8000');
      expect(find.textContaining('Connected to MealLens.'), findsOneWidget);
      expect(find.textContaining('sample detections'), findsOneWidget);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(app.prefs.getString('theme_mode'), 'dark');
    });
  });
}
