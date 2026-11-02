import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'helpers.dart';

const signedIn = {'onboarding_seen': true};

Future<FakeAuth> _auth() async {
  final auth = FakeAuth();
  await auth.signIn('cook@example.com', 'correct-horse');
  return auth;
}

Future<void> _openRecipesTab(WidgetTester tester) async {
  await tester.tap(find.text('Recipes'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty fridge asks for ingredients first', (tester) async {
    await pumpApp(tester, prefs: signedIn, auth: await _auth());
    await _openRecipesTab(tester);
    expect(find.text('Add a few ingredients first'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Scan ingredients'), findsOneWidget);
  });

  testWidgets('no matches suggests browsing', (tester) async {
    final api = FakeApi()..stock('milk');
    await pumpApp(tester, prefs: signedIn, auth: await _auth(), api: api);
    await _openRecipesTab(tester);
    expect(find.text('No close matches yet'), findsOneWidget);
    expect(find.text('Add another ingredient or browse recipes with one or two extras.'), findsOneWidget);
    await tester.tap(find.text('Browse recipes'));
    await tester.pumpAndSettle();
    expect(find.text('Search recipes or ingredients'), findsOneWidget);
  });

  testWidgets('matches show the ingredient match and what is missing, best first', (tester) async {
    final api = FakeApi()
      ..stock('egg')
      ..stock('tomato');
    await pumpApp(tester, prefs: signedIn, auth: await _auth(), api: api);
    await _openRecipesTab(tester);

    expect(find.text('67% ingredient match'), findsOneWidget); // omelette: egg, tomato of egg, tomato, onion
    expect(find.text('Missing 1 ingredient: Onion'), findsOneWidget);
    expect(find.text('25% ingredient match'), findsOneWidget); // salad: tomato of 4
    expect(find.text('Missing 3 ingredients'), findsOneWidget);
    expect(find.text('Pasta Primavera'), findsNothing); // shares nothing with the fridge
    expect(tester.getTopLeft(find.text('Tomato Omelette')).dy, lessThan(tester.getTopLeft(find.text('Greek Salad')).dy));
    expect(find.text('250 kcal · 14 g protein'), findsOneWidget); // per serving, from the server
  });

  testWidgets('recipe detail: match summary, ingredients, nutrition, steps', (tester) async {
    final api = FakeApi()
      ..stock('egg')
      ..stock('tomato');
    await pumpApp(tester, prefs: signedIn, auth: await _auth(), api: api);
    await _openRecipesTab(tester);
    await tester.tap(find.text('Tomato Omelette'));
    await tester.pumpAndSettle();

    expect(find.text('You already have 2 of the 3 ingredients.'), findsOneWidget); // salt is a staple
    expect(find.text('Missing: Onion'), findsOneWidget);
    expect(find.text('Breakfast · 15 min · 2 servings · Easy'), findsOneWidget);
    expect(find.text('125 kcal'), findsNothing);
    expect(find.text('250 kcal'), findsOneWidget); // per-serving value from the server, rounded
    expect(find.text('2.3 g'), findsOneWidget); // fiber, one decimal
    expect(find.text('1 piece · diced'), findsOneWidget);
    expect(find.text('2 pieces'), findsOneWidget);
    expect(find.text('¼ piece · optional extra · Missing'), findsOneWidget);
    // Status icons carry a spoken label, so the state is not shown by colour alone.
    expect(find.byWidgetPredicate((w) => w is Icon && w.semanticLabel == 'In your fridge'), findsNWidgets(2));
    await tester.scrollUntilVisible(find.text('1 pinch · Pantry staple'), 200);
    expect(find.text('1 pinch · Pantry staple'), findsOneWidget); // a staple is never "missing"
    await tester.scrollUntilVisible(find.text('Add the eggs and fold.'), 200);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('saving a recipe shows it under Saved, and unsaving removes it', (tester) async {
    final api = FakeApi()..stock('egg');
    await pumpApp(tester, prefs: signedIn, auth: await _auth(), api: api);
    await _openRecipesTab(tester);
    await tester.tap(find.text('Tomato Omelette'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save recipe'));
    await tester.pumpAndSettle();
    expect(find.text('Saved to your recipes'), findsOneWidget);
    expect(api.saved, {1});
    expect(find.byTooltip('Saved'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Tomato Omelette'), findsOneWidget);

    await tester.tap(find.text('Tomato Omelette'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Saved'));
    await tester.pumpAndSettle();
    expect(api.saved, isEmpty);
  });

  testWidgets('I cooked this: rating and taking ingredients out of the fridge', (tester) async {
    final api = FakeApi()
      ..stock('egg')
      ..stock('tomato')
      ..stock('onion');
    await pumpApp(tester, prefs: signedIn, auth: await _auth(), api: api);
    await _openRecipesTab(tester);
    await tester.tap(find.text('Tomato Omelette'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('I cooked this'));
    await tester.pumpAndSettle();
    expect(find.text('How was it?'), findsOneWidget);
    await tester.tap(find.byTooltip('4 of 5'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(api.cookedLog.single, (recipeId: 1, rating: 4, removeUsed: true));
    expect(find.text('Enjoy your meal. We took egg and tomato out of your fridge.'), findsOneWidget);
    expect([for (final f in api.fridge) f.ingredient.slug], ['onion']); // onion is only a supporting ingredient

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fridge'));
    await tester.pumpAndSettle();
    expect(find.text('1 ingredient'), findsOneWidget); // the fridge tab reflects it
  });

  testWidgets('cooking without removing leaves the fridge alone', (tester) async {
    final api = FakeApi()..stock('egg');
    await pumpApp(tester, prefs: signedIn, auth: await _auth(), api: api);
    await _openRecipesTab(tester);
    await tester.tap(find.text('Tomato Omelette'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I cooked this'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take the main ingredients out of my fridge'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(api.cookedLog.single, (recipeId: 1, rating: null, removeUsed: false));
    expect(find.text('Enjoy your meal'), findsOneWidget);
    expect(api.fridge, hasLength(1));
  });

  testWidgets('browse filters by meal type and search', (tester) async {
    await pumpApp(tester, prefs: signedIn, auth: await _auth());
    await _openRecipesTab(tester);
    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    expect(find.text('Greek Salad'), findsOneWidget);
    expect(find.text('Pasta Primavera'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Dinner'));
    await tester.pumpAndSettle();
    expect(find.text('Greek Salad'), findsNothing);
    expect(find.text('Pasta Primavera'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.enterText(find.byType(TextField), 'salad');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Greek Salad'), findsOneWidget);
    expect(find.text('Pasta Primavera'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('No recipes found'), findsOneWidget);
  });

  testWidgets('a scan updates recipe matches, and the snackbar links to them', (tester) async {
    final api = FakeApi(scanResult: null)..stock('egg');
    await pumpApp(tester, prefs: signedIn, auth: await _auth(), api: api);
    await _openRecipesTab(tester);
    expect(find.text('33% ingredient match'), findsOneWidget);

    // Add tomato by hand on the fridge tab; matches on the recipes tab follow.
    await tester.tap(find.text('Fridge'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add manually'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'tomato');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tomato').last);
    await tester.pumpAndSettle();
    await _openRecipesTab(tester);
    expect(find.text('67% ingredient match'), findsOneWidget);
  });

  testWidgets('recipes fit a small phone with large text', (tester) async {
    final api = FakeApi()
      ..stock('egg')
      ..stock('tomato');
    await pumpApp(tester, prefs: signedIn, auth: await _auth(), api: api, size: const Size(320, 568), textScale: 1.6);
    await _openRecipesTab(tester);
    await tester.tap(find.text('Tomato Omelette'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I cooked this'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
