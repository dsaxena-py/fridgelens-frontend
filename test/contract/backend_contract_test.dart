// Runs the app's real HTTP client against a running MealLens backend.
// Skipped unless MEALLENS_API_URL and MEALLENS_TOKEN are set; see README "Contract test".
@Tags(['contract'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meallens/data/api.dart';
import 'package:meallens/data/models.dart';

void main() {
  final url = Platform.environment['MEALLENS_API_URL'];
  final token = Platform.environment['MEALLENS_TOKEN'];
  final photo = Platform.environment['MEALLENS_PHOTO'];
  final skip = url == null || token == null || photo == null ? 'set MEALLENS_API_URL, MEALLENS_TOKEN and MEALLENS_PHOTO' : null;

  // Plain test() (no widget binding), so real HTTP is allowed.
  test('scan, confirm and manage the fridge against the real API', () async {
    final api = HttpMealLensApi(baseUrl: url!, token: () async => token);

    expect(await checkServer(url), isNotEmpty);
    expect(await api.inventory(), isEmpty);
    final search = await api.searchIngredients('red onion');
    expect(search.first.slug, 'onion');

    final scan = await api.uploadScan(File(photo!));
    expect(scan.status, 'awaiting_review');
    expect(scan.detections, isNotEmpty);
    expect(scan.imageWidth, greaterThan(0));

    final decisions = [
      for (final d in scan.detections)
        d.needsCheck
            ? DetectionDecision(d.id, ReviewAction.reject)
            : DetectionDecision(d.id, ReviewAction.relabel, search.first.id).copyIfNotFirst(d, scan.detections.first),
    ];
    final milk = (await api.searchIngredients('milk')).first;
    final fridge = await api.confirmScan(scan.id, decisions, [milk.id]);
    final slugs = {for (final i in fridge) i.ingredient.slug};
    expect(slugs, contains('milk'));
    expect(slugs, contains('onion'));
    expect(fridge.every((i) => i.daysLeft != null), isTrue);

    await expectLater(api.confirmScan(scan.id, decisions, const []),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)));

    final bread = (await api.searchIngredients('bread')).first;
    await api.addToFridge(bread.id);
    var items = await api.inventory();
    final breadItem = items.firstWhere((i) => i.ingredient.slug == 'bread');
    await api.setExpiry(breadItem.id, DateTime(2026, 12, 24));
    items = await api.inventory();
    expect(items.firstWhere((i) => i.id == breadItem.id).expiresAt, DateTime(2026, 12, 24));
    await api.setExpiry(breadItem.id, null);
    items = await api.inventory();
    expect(items.firstWhere((i) => i.id == breadItem.id).expiresAt, isNull);

    await api.removeItem(breadItem.id);
    expect((await api.inventory()).any((i) => i.id == breadItem.id), isFalse);

    // Recipes against the seeded catalog (120 recipes).
    final recs = await api.recommendations(limit: 5);
    expect(recs.inventoryCount, greaterThan(0));
    expect(recs.items, isNotEmpty);
    expect(recs.items.first.rank, 1);
    expect(recs.items.first.recipe.nutrition, isNotNull);
    final top = recs.items.first;

    final detail = await api.recipe(top.recipe.id);
    expect(detail.steps, isNotEmpty);
    expect(detail.coverage.have, greaterThan(0));
    // The app's "have X of Y" uses the same rule as the server's plain match score.
    expect(detail.coverage.have / detail.coverage.total, closeTo(top.matchScore, 0.001));

    final snacks = await api.recipes(mealType: 'snack');
    expect(snacks, hasLength(15));
    expect((await api.recipes(query: 'omelette')).map((r) => r.title), contains('Tomato Omelette'));

    await api.setSaved(top.recipe.id, true);
    expect((await api.savedRecipes()).map((r) => r.id), [top.recipe.id]);
    expect((await api.recipe(top.recipe.id)).saved, isTrue);
    await api.setSaved(top.recipe.id, false);
    expect(await api.savedRecipes(), isEmpty);

    final before = (await api.inventory()).length;
    final cooked = await api.cooked(top.recipe.id, rating: 5, removeUsed: true);
    expect((await api.inventory()).length, before - cooked.removed.length);

    final noAuth = HttpMealLensApi(baseUrl: url, token: () async => 'not-a-token');
    await expectLater(noAuth.inventory(), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Please sign in again.')));
  }, skip: skip);
}

extension on DetectionDecision {
  /// Accept every detection except the first, which is relabelled, to exercise both actions.
  DetectionDecision copyIfNotFirst(Detection d, Detection first) =>
      d.id == first.id ? this : DetectionDecision(d.id, ReviewAction.accept);
}
