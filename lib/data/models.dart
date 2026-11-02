// Models for the MealLens API (fridgelens-backend/app/schemas.py).

double _d(Object? v) => (v as num).toDouble();
double? _dn(Object? v) => v == null ? null : (v as num).toDouble();
DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);
List<String> _strings(Object? v) => [for (final s in (v as List? ?? const [])) s as String];

class IngredientRef {
  const IngredientRef({required this.id, required this.slug, required this.name});

  factory IngredientRef.fromJson(Map<String, dynamic> j) =>
      IngredientRef(id: j['id'] as int, slug: j['slug'] as String, name: j['name'] as String);

  final int id;
  final String slug;
  final String name;

  @override
  bool operator ==(Object other) => other is IngredientRef && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class Ingredient extends IngredientRef {
  const Ingredient({
    required super.id,
    required super.slug,
    required super.name,
    required this.category,
    required this.isPantryStaple,
    required this.isDetectable,
    required this.defaultUnit,
    required this.allergens,
  });

  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
        id: j['id'] as int,
        slug: j['slug'] as String,
        name: j['name'] as String,
        category: j['category'] as String,
        isPantryStaple: j['is_pantry_staple'] as bool,
        isDetectable: j['is_detectable'] as bool,
        defaultUnit: j['default_unit'] as String,
        allergens: _strings(j['allergens']),
      );

  final String category;
  final bool isPantryStaple;
  final bool isDetectable;
  final String defaultUnit;
  final List<String> allergens;
}

enum Freshness { fresh, useSoon, pastBest, unknown }

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.ingredient,
    this.quantity,
    this.unit,
    required this.source,
    this.expiresAt,
    this.daysLeft,
    required this.addedAt,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
        id: j['id'] as String,
        ingredient: Ingredient.fromJson(j['ingredient'] as Map<String, dynamic>),
        quantity: _dn(j['quantity']),
        unit: j['unit'] as String?,
        source: j['source'] as String,
        expiresAt: _date(j['expires_at']),
        daysLeft: j['days_left'] as int?,
        addedAt: DateTime.parse(j['added_at'] as String),
      );

  final String id;
  final Ingredient ingredient;
  final double? quantity;
  final String? unit;
  final String source;
  final DateTime? expiresAt;
  final int? daysLeft;
  final DateTime addedAt;

  Freshness get freshness {
    final d = daysLeft;
    if (d == null) return Freshness.unknown;
    if (d < 0) return Freshness.pastBest;
    if (d <= 2) return Freshness.useSoon;
    return Freshness.fresh;
  }
}

class Box {
  const Box(this.xMin, this.yMin, this.xMax, this.yMax);

  factory Box.fromJson(Map<String, dynamic> j) => Box(_d(j['x_min']), _d(j['y_min']), _d(j['x_max']), _d(j['y_max']));

  final double xMin, yMin, xMax, yMax;
}

class Detection {
  const Detection({
    required this.id,
    required this.ingredient,
    required this.confidence,
    required this.box,
    required this.needsCheck,
  });

  factory Detection.fromJson(Map<String, dynamic> j) => Detection(
        id: j['id'] as int,
        ingredient: IngredientRef.fromJson(j['ingredient'] as Map<String, dynamic>),
        confidence: _d(j['confidence']),
        box: Box.fromJson(j['box'] as Map<String, dynamic>),
        needsCheck: j['needs_check'] as bool,
      );

  final int id;
  final IngredientRef ingredient;
  final double confidence;
  final Box box;
  final bool needsCheck;
}

class Scan {
  const Scan({
    required this.id,
    required this.status,
    this.imageUrl,
    this.imageWidth,
    this.imageHeight,
    this.errorMessage,
    required this.detections,
  });

  factory Scan.fromJson(Map<String, dynamic> j) => Scan(
        id: j['id'] as String,
        status: j['status'] as String,
        imageUrl: j['image_url'] as String?,
        imageWidth: j['image_width'] as int?,
        imageHeight: j['image_height'] as int?,
        errorMessage: j['error_message'] as String?,
        detections: [for (final d in j['detections'] as List) Detection.fromJson(d as Map<String, dynamic>)],
      );

  final String id;
  final String status;
  final String? imageUrl;
  final int? imageWidth;
  final int? imageHeight;
  final String? errorMessage;
  final List<Detection> detections;

  bool get failed => status == 'failed';
}

class Nutrition {
  const Nutrition({required this.kcal, required this.proteinG, required this.carbsG, required this.fatG, required this.fiberG});

  factory Nutrition.fromJson(Map<String, dynamic> j) => Nutrition(
        kcal: _d(j['kcal']),
        proteinG: _d(j['protein_g']),
        carbsG: _d(j['carbs_g']),
        fatG: _d(j['fat_g']),
        fiberG: _d(j['fiber_g']),
      );

  final double kcal, proteinG, carbsG, fatG, fiberG;
}

class RecipeSummary {
  const RecipeSummary({
    required this.id,
    required this.title,
    this.description,
    this.cuisine,
    required this.mealType,
    required this.servings,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.difficulty,
    required this.dietaryTags,
    this.imageUrl,
    this.nutrition,
  });

  factory RecipeSummary.fromJson(Map<String, dynamic> j) => RecipeSummary(
        id: j['id'] as int,
        title: j['title'] as String,
        description: j['description'] as String?,
        cuisine: j['cuisine'] as String?,
        mealType: j['meal_type'] as String,
        servings: j['servings'] as int,
        prepMinutes: j['prep_minutes'] as int,
        cookMinutes: j['cook_minutes'] as int,
        difficulty: j['difficulty'] as String,
        dietaryTags: _strings(j['dietary_tags']),
        imageUrl: j['image_url'] as String?,
        nutrition: j['nutrition_per_serving'] == null
            ? null
            : Nutrition.fromJson(j['nutrition_per_serving'] as Map<String, dynamic>),
      );

  final int id;
  final String title;
  final String? description;
  final String? cuisine;
  final String mealType;
  final int servings;
  final int prepMinutes;
  final int cookMinutes;
  final String difficulty;
  final List<String> dietaryTags;
  final String? imageUrl;
  final Nutrition? nutrition;

  int get totalMinutes => prepMinutes + cookMinutes;
}

class Recommendation {
  const Recommendation({
    required this.rank,
    required this.recipe,
    required this.matchScore,
    required this.weightedScore,
    required this.missingCount,
    required this.missingIngredients,
  });

  factory Recommendation.fromJson(Map<String, dynamic> j) => Recommendation(
        rank: j['rank'] as int,
        recipe: RecipeSummary.fromJson(j['recipe'] as Map<String, dynamic>),
        matchScore: _d(j['match_score']),
        weightedScore: _d(j['weighted_score']),
        missingCount: j['missing_count'] as int,
        missingIngredients: _strings(j['missing_ingredients']),
      );

  final int rank;
  final RecipeSummary recipe;
  final double matchScore;
  final double weightedScore;
  final int missingCount;
  final List<String> missingIngredients;

  /// The match shown to people: weighted, so a missing garnish costs less than a missing core ingredient.
  int get matchPercent => (weightedScore * 100).round();
}

class Recommendations {
  const Recommendations({required this.runId, required this.inventoryCount, required this.items});

  factory Recommendations.fromJson(Map<String, dynamic> j) => Recommendations(
        runId: j['run_id'] as String,
        inventoryCount: j['inventory_count'] as int,
        items: [for (final i in j['items'] as List) Recommendation.fromJson(i as Map<String, dynamic>)],
      );

  final String runId;
  final int inventoryCount;
  final List<Recommendation> items;
}

class RecipeIngredient {
  const RecipeIngredient({
    required this.ingredient,
    required this.quantity,
    required this.unit,
    required this.role,
    this.note,
    required this.isPantryStaple,
    required this.inFridge,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) => RecipeIngredient(
        ingredient: IngredientRef.fromJson(j['ingredient'] as Map<String, dynamic>),
        quantity: _d(j['quantity']),
        unit: j['unit'] as String,
        role: j['role'] as String,
        note: j['note'] as String?,
        isPantryStaple: j['is_pantry_staple'] as bool,
        inFridge: j['in_fridge'] as bool,
      );

  final IngredientRef ingredient;
  final double quantity;
  final String unit;
  final String role;
  final String? note;
  final bool isPantryStaple;
  final bool inFridge;
}

class RecipeDetail {
  const RecipeDetail({required this.summary, required this.ingredients, required this.steps, required this.saved});

  factory RecipeDetail.fromJson(Map<String, dynamic> j) => RecipeDetail(
        summary: RecipeSummary.fromJson(j),
        ingredients: [for (final i in j['ingredients'] as List) RecipeIngredient.fromJson(i as Map<String, dynamic>)],
        steps: _strings(j['steps']),
        saved: j['saved'] as bool,
      );

  final RecipeSummary summary;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final bool saved;

  /// Ingredients you have out of those that count, matching the backend's match score:
  /// pantry staples (salt, oil, spices) are assumed to be in the kitchen.
  ({int have, int total}) get coverage {
    final counted = [for (final i in ingredients) if (!i.isPantryStaple) i];
    return (have: counted.where((i) => i.inFridge).length, total: counted.length);
  }

  RecipeDetail copyWith({bool? saved}) =>
      RecipeDetail(summary: summary, ingredients: ingredients, steps: steps, saved: saved ?? this.saved);
}

/// What "I cooked this" returned: the ingredients taken out of the fridge.
class CookedResult {
  const CookedResult(this.removed);

  final List<IngredientRef> removed;
}

/// The user's decision for one detection on the review screen.
enum ReviewAction { accept, reject, relabel }

class DetectionDecision {
  const DetectionDecision(this.detectionId, this.action, [this.ingredientId]);

  final int detectionId;
  final ReviewAction action;
  final int? ingredientId;

  Map<String, dynamic> toJson() => {
        'detection_id': detectionId,
        'action': action.name,
        if (ingredientId != null) 'ingredient_id': ingredientId,
      };
}
