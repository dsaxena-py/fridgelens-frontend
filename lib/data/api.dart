import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'models.dart';

/// A request that failed, with a message that is safe to show people.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Everything the app asks the MealLens backend. Widget tests swap in a fake.
abstract interface class MealLensApi {
  Future<List<Ingredient>> searchIngredients(String query);
  Future<Scan> uploadScan(File image);
  Future<List<InventoryItem>> confirmScan(String scanId, List<DetectionDecision> decisions, List<int> additions);
  Future<List<InventoryItem>> inventory();
  Future<void> addToFridge(int ingredientId);
  Future<void> setExpiry(String itemId, DateTime? expiresAt);
  Future<void> removeItem(String itemId);
  Future<Recommendations> recommendations({int limit = 30});
  Future<List<RecipeSummary>> recipes({String? query, String? mealType});
  Future<List<RecipeSummary>> savedRecipes();
  Future<RecipeDetail> recipe(int id);
  Future<void> setSaved(int recipeId, bool saved);
  Future<CookedResult> cooked(int recipeId, {int? rating, bool removeUsed = false});
}

/// Checks a server address without signing in; returns the detector the server runs.
Future<String> checkServer(String baseUrl, {http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final r = await c.get(Uri.parse('${_trim(baseUrl)}/health')).timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) throw ApiException('The server answered, but with an error (${r.statusCode}).');
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    return body['detector'] as String? ?? 'unknown';
  } on ApiException {
    rethrow;
  } on FormatException {
    throw ApiException("That address answered, but it isn't the MealLens server.");
  } on Exception {
    throw ApiException("We couldn't reach that address. Check it, and that the phone and laptop share a Wi-Fi network.");
  } finally {
    if (client == null) c.close();
  }
}

String _trim(String url) => url.trim().replaceAll(RegExp(r'/+$'), '');

class HttpMealLensApi implements MealLensApi {
  HttpMealLensApi({required this.baseUrl, required this.token, http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final Future<String?> Function() token;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String?>? query]) {
    final q = {for (final e in (query ?? {}).entries) if (e.value != null && e.value!.isNotEmpty) e.key: e.value!};
    return Uri.parse('${_trim(baseUrl)}/v1$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final t = await token();
    if (t == null) throw ApiException('Please sign in again.', statusCode: 401);
    return {'Authorization': 'Bearer $t', if (json) 'Content-Type': 'application/json'};
  }

  Future<dynamic> _send(Future<http.Response> Function() call, {Duration timeout = const Duration(seconds: 30)}) async {
    final http.Response r;
    try {
      r = await call().timeout(timeout);
    } on TimeoutException {
      throw ApiException('MealLens is taking too long to answer. Try again in a moment.');
    } on SocketException {
      throw ApiException("We couldn't reach MealLens. Check the server address in Settings, and that the phone and laptop share a Wi-Fi network.");
    } on http.ClientException {
      throw ApiException("We couldn't reach MealLens. Check the server address in Settings.");
    }
    if (r.statusCode == 204 || r.body.isEmpty) return null;
    final dynamic body;
    try {
      body = jsonDecode(utf8.decode(r.bodyBytes));
    } on FormatException {
      throw ApiException('MealLens sent an unexpected answer. Check the server address in Settings.', statusCode: r.statusCode);
    }
    if (r.statusCode >= 400) throw ApiException(_friendly(r.statusCode, body), statusCode: r.statusCode);
    return body;
  }

  String _friendly(int status, dynamic body) {
    switch (status) {
      case 401:
        return 'Please sign in again.';
      case 409:
        return 'This scan has already been confirmed.';
      case 413:
        return 'That photo is too large. Try a smaller one.';
      case 415:
        return "We couldn't read that image. Try a JPEG or PNG photo.";
      case 502:
      case 503:
        return 'MealLens is having trouble right now. Try again in a moment.';
    }
    final detail = body is Map ? body['detail'] : null;
    return detail is String ? detail : 'Something went wrong. Try again.';
  }

  Future<dynamic> _get(String path, [Map<String, String?>? q]) async {
    final h = await _headers();
    return _send(() => _client.get(_uri(path, q), headers: h));
  }

  Future<dynamic> _json(String method, String path, Object? body) async {
    final h = await _headers(json: true);
    final req = http.Request(method, _uri(path))
      ..headers.addAll(h)
      ..body = jsonEncode(body ?? {});
    return _send(() async => http.Response.fromStream(await _client.send(req)));
  }

  List<T> _list<T>(dynamic body, T Function(Map<String, dynamic>) f) =>
      [for (final e in body as List) f(e as Map<String, dynamic>)];

  @override
  Future<List<Ingredient>> searchIngredients(String query) async =>
      _list(await _get('/ingredients', {'q': query, 'limit': '30'}), Ingredient.fromJson);

  @override
  Future<Scan> uploadScan(File image) async {
    final h = await _headers();
    final req = http.MultipartRequest('POST', _uri('/scans'))
      ..headers.addAll(h)
      ..files.add(await http.MultipartFile.fromPath('image', image.path, contentType: MediaType('image', 'jpeg')));
    // Upload plus detection on a laptop CPU: allow longer than ordinary requests.
    final body = await _send(() async => http.Response.fromStream(await _client.send(req)), timeout: const Duration(seconds: 90));
    return Scan.fromJson(body as Map<String, dynamic>);
  }

  @override
  Future<List<InventoryItem>> confirmScan(String scanId, List<DetectionDecision> decisions, List<int> additions) async =>
      _list(
        await _json('POST', '/scans/$scanId/confirm', {
          'decisions': [for (final d in decisions) d.toJson()],
          'additions': [for (final id in additions) {'ingredient_id': id}],
        }),
        InventoryItem.fromJson,
      );

  @override
  Future<List<InventoryItem>> inventory() async => _list(await _get('/inventory'), InventoryItem.fromJson);

  @override
  Future<void> addToFridge(int ingredientId) => _json('POST', '/inventory', {'ingredient_id': ingredientId});

  @override
  Future<void> setExpiry(String itemId, DateTime? expiresAt) => _json('PATCH', '/inventory/$itemId', {
        'expires_at': expiresAt == null
            ? null
            : '${expiresAt.year.toString().padLeft(4, '0')}-${expiresAt.month.toString().padLeft(2, '0')}-${expiresAt.day.toString().padLeft(2, '0')}',
      });

  @override
  Future<void> removeItem(String itemId) async {
    final h = await _headers();
    await _send(() => _client.delete(_uri('/inventory/$itemId'), headers: h));
  }

  @override
  Future<Recommendations> recommendations({int limit = 30}) async =>
      Recommendations.fromJson(await _get('/recommendations', {'limit': '$limit'}) as Map<String, dynamic>);

  @override
  Future<List<RecipeSummary>> recipes({String? query, String? mealType}) async =>
      _list(await _get('/recipes', {'q': query, 'meal_type': mealType, 'limit': '100'}), RecipeSummary.fromJson);

  @override
  Future<List<RecipeSummary>> savedRecipes() async => _list(await _get('/recipes/saved'), RecipeSummary.fromJson);

  @override
  Future<RecipeDetail> recipe(int id) async => RecipeDetail.fromJson(await _get('/recipes/$id') as Map<String, dynamic>);

  @override
  Future<void> setSaved(int recipeId, bool saved) async {
    final h = await _headers();
    final uri = _uri('/recipes/$recipeId/save');
    await _send(() => saved ? _client.put(uri, headers: h) : _client.delete(uri, headers: h));
  }

  @override
  Future<CookedResult> cooked(int recipeId, {int? rating, bool removeUsed = false}) async {
    final body = await _json('POST', '/recipes/$recipeId/cooked', {'rating': rating, 'remove_used': removeUsed});
    final removed = (body as Map<String, dynamic>)['removed_from_fridge'] as List;
    return CookedResult([for (final i in removed) IngredientRef.fromJson(i as Map<String, dynamic>)]);
  }
}
