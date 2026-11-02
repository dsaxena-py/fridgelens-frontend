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
