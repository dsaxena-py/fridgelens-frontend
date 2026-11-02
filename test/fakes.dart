import 'dart:io';
import 'dart:typed_data';

import 'package:meallens/data/api.dart';
import 'package:meallens/data/models.dart';

Ingredient ingredient(int id, String slug, String name, {String category = 'produce', bool staple = false}) => Ingredient(
      id: id,
      slug: slug,
      name: name,
      category: category,
      isPantryStaple: staple,
      isDetectable: true,
      defaultUnit: 'piece',
      allergens: const [],
    );

final catalog = [
  ingredient(1, 'egg', 'Egg', category: 'protein'),
  ingredient(2, 'tomato', 'Tomato'),
  ingredient(3, 'onion', 'Onion'),
  ingredient(4, 'bell_pepper', 'Bell pepper'),
  ingredient(5, 'milk', 'Milk', category: 'dairy'),
  ingredient(6, 'leafy_greens', 'Leafy greens'),
];

Detection detection(int id, Ingredient ing, double confidence, double x) => Detection(
      id: id,
      ingredient: IngredientRef(id: ing.id, slug: ing.slug, name: ing.name),
      confidence: confidence,
      box: Box(x, 0.3, x + 0.2, 0.6),
      needsCheck: confidence < 0.5,
    );

/// In-memory stand-in for the backend that records what the app sends.
class FakeApi implements MealLensApi {
  FakeApi({List<InventoryItem>? fridge, this.scanResult}) : fridge = fridge ?? [];

  final List<InventoryItem> fridge;
  Scan? scanResult;
  Object? uploadError;
  final confirmed = <({String scanId, List<DetectionDecision> decisions, List<int> additions})>[];
  final removed = <String>[];
  int _ids = 0;

  InventoryItem _item(Ingredient ing, {int? daysLeft, String source = 'scan'}) => InventoryItem(
        id: 'item-${++_ids}',
        ingredient: ing,
        source: source,
        daysLeft: daysLeft,
        expiresAt: daysLeft == null ? null : DateTime(2026, 11, 2).add(Duration(days: daysLeft)),
        addedAt: DateTime(2026, 11, 2),
      );

  void stock(String slug, {int? daysLeft}) => fridge.add(_item(catalog.firstWhere((i) => i.slug == slug), daysLeft: daysLeft));

  @override
  Future<List<Ingredient>> searchIngredients(String query) async =>
      [for (final i in catalog) if (i.name.toLowerCase().contains(query.toLowerCase())) i];

  @override
  Future<Scan> uploadScan(File image) async {
    if (uploadError != null) throw uploadError!;
    return scanResult!;
  }

  @override
  Future<List<InventoryItem>> confirmScan(String scanId, List<DetectionDecision> decisions, List<int> additions) async {
    confirmed.add((scanId: scanId, decisions: decisions, additions: additions));
    final dets = {for (final d in scanResult!.detections) d.id: d};
    final ids = <int>{
      for (final d in decisions)
        if (d.action == ReviewAction.accept) dets[d.detectionId]!.ingredient.id else if (d.action == ReviewAction.relabel) d.ingredientId!,
      ...additions,
    };
    for (final id in ids) {
      if (!fridge.any((f) => f.ingredient.id == id)) fridge.add(_item(catalog.firstWhere((c) => c.id == id), daysLeft: 7));
    }
    return List.of(fridge);
  }

  @override
  Future<List<InventoryItem>> inventory() async => List.of(fridge);

  @override
  Future<void> addToFridge(int ingredientId) async {
    if (!fridge.any((f) => f.ingredient.id == ingredientId)) {
      fridge.add(_item(catalog.firstWhere((c) => c.id == ingredientId), daysLeft: 7, source: 'manual'));
    }
  }

  @override
  Future<void> setExpiry(String itemId, DateTime? expiresAt) async {}

  @override
  Future<void> removeItem(String itemId) async {
    removed.add(itemId);
    fridge.removeWhere((f) => f.id == itemId);
  }

  // ---------- Recipes ----------

  final saved = <int>{};
  final cookedLog = <({int recipeId, int? rating, bool removeUsed})>[];

  bool _has(String slug) => fridge.any((f) => f.ingredient.slug == slug);

  @override
  Future<Recommendations> recommendations({int limit = 30}) async {
    final ranked = <Recommendation>[];
    for (final r in recipeBook) {
      final counted = [for (final i in r.ingredients) if (!i.isPantryStaple) i];
      final have = counted.where((i) => _has(i.ingredient.slug)).length;
      if (have == 0) continue;
      final missing = [for (final i in counted) if (!_has(i.ingredient.slug)) i.ingredient.name];
      ranked.add(Recommendation(
        rank: 0,
        recipe: r.summary,
        matchScore: have / counted.length,
        weightedScore: have / counted.length,
        missingCount: missing.length,
        missingIngredients: missing,
      ));
    }
    ranked.sort((a, b) => b.weightedScore.compareTo(a.weightedScore));
    return Recommendations(runId: 'run', inventoryCount: fridge.length, items: [
      for (final (i, r) in ranked.indexed)
        Recommendation(rank: i + 1, recipe: r.recipe, matchScore: r.matchScore, weightedScore: r.weightedScore,
            missingCount: r.missingCount, missingIngredients: r.missingIngredients),
    ]);
  }

  @override
  Future<List<RecipeSummary>> recipes({String? query, String? mealType}) async => [
        for (final r in recipeBook)
          if ((mealType == null || r.summary.mealType == mealType) &&
              (query == null || query.isEmpty || r.summary.title.toLowerCase().contains(query.toLowerCase())))
            r.summary,
      ];

  @override
  Future<List<RecipeSummary>> savedRecipes() async => [for (final r in recipeBook) if (saved.contains(r.summary.id)) r.summary];

  @override
  Future<RecipeDetail> recipe(int id) async {
    final r = recipeBook.firstWhere((r) => r.summary.id == id, orElse: () => throw ApiException('recipe not found', statusCode: 404));
    return RecipeDetail(
      summary: r.summary,
      steps: r.steps,
      saved: saved.contains(id),
      ingredients: [
        for (final i in r.ingredients)
          RecipeIngredient(ingredient: i.ingredient, quantity: i.quantity, unit: i.unit, role: i.role, note: i.note,
              isPantryStaple: i.isPantryStaple, inFridge: _has(i.ingredient.slug)),
      ],
    );
  }

  @override
  Future<void> setSaved(int recipeId, bool saved) async => saved ? this.saved.add(recipeId) : this.saved.remove(recipeId);

  @override
  Future<CookedResult> cooked(int recipeId, {int? rating, bool removeUsed = false}) async {
    cookedLog.add((recipeId: recipeId, rating: rating, removeUsed: removeUsed));
    if (!removeUsed) return const CookedResult([]);
    final r = recipeBook.firstWhere((r) => r.summary.id == recipeId);
    final core = {for (final i in r.ingredients) if (i.role == 'core' && !i.isPantryStaple) i.ingredient.slug};
    final removedNow = [for (final f in fridge) if (core.contains(f.ingredient.slug)) f.ingredient];
    fridge.removeWhere((f) => core.contains(f.ingredient.slug));
    return CookedResult([for (final i in removedNow) IngredientRef(id: i.id, slug: i.slug, name: i.name)]);
  }
}

RecipeIngredient _ri(String slug, double qty, String unit, {String role = 'core', String? note, bool staple = false}) {
  final known = catalog.where((c) => c.slug == slug);
  final ing = known.isNotEmpty ? known.first : ingredient(100 + slug.length, slug, slug[0].toUpperCase() + slug.substring(1));
  return RecipeIngredient(
      ingredient: IngredientRef(id: ing.id, slug: ing.slug, name: ing.name),
      quantity: qty, unit: unit, role: role, note: note, isPantryStaple: staple, inFridge: false);
}

RecipeSummary _summary(int id, String title, String meal, double kcal, double protein) => RecipeSummary(
      id: id,
      title: title,
      description: 'A test recipe.',
      cuisine: 'Test',
      mealType: meal,
      servings: 2,
      prepMinutes: 5,
      cookMinutes: 10,
      difficulty: 'easy',
      dietaryTags: const ['vegetarian'],
      nutrition: Nutrition(kcal: kcal, proteinG: protein, carbsG: 12, fatG: 9.5, fiberG: 2.25),
    );

final recipeBook = [
  (
    summary: _summary(1, 'Tomato Omelette', 'breakfast', 249.6, 14.4),
    ingredients: [
      _ri('egg', 2, 'piece'),
      _ri('tomato', 1, 'piece', note: 'diced'),
      _ri('onion', 0.25, 'piece', role: 'supporting'),
      _ri('salt', 1, 'pinch', staple: true),
    ],
    steps: ['Beat the eggs.', 'Cook the tomato and onion.', 'Add the eggs and fold.'],
  ),
  (
    summary: _summary(2, 'Greek Salad', 'lunch', 310, 9),
    ingredients: [
      _ri('tomato', 2, 'piece'),
      _ri('bell_pepper', 1, 'piece'),
      _ri('onion', 0.5, 'piece'),
      _ri('feta', 100, 'g'),
    ],
    steps: ['Chop everything.', 'Dress and serve.'],
  ),
  (
    summary: _summary(3, 'Pasta Primavera', 'dinner', 540, 18),
    ingredients: [_ri('pasta', 350, 'g'), _ri('bell_pepper', 1, 'piece')],
    steps: ['Cook the pasta.', 'Toss with vegetables.'],
  ),
];

/// A real 1x1 PNG on disk, standing in for a camera photo.
File testPhoto() {
  final f = File('${Directory.systemTemp.createTempSync('meallens').path}/photo.png');
  f.writeAsBytesSync(Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01,
    0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02, 0xFE, 0xA7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
    0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]));
  return f;
}
