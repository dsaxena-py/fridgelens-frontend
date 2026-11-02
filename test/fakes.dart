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
}

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
