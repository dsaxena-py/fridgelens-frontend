import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../data/api.dart';
import '../data/auth.dart';
import '../data/models.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('overridden in main'));

final authProvider = Provider<AuthService>((ref) => throw UnimplementedError('overridden in main'));

/// Settings kept on the device: theme, backend address, and whether onboarding was seen.
class AppSettings {
  const AppSettings({required this.themeMode, required this.apiBaseUrl, required this.onboardingSeen});

  final ThemeMode themeMode;
  final String apiBaseUrl;
  final bool onboardingSeen;

  AppSettings copyWith({ThemeMode? themeMode, String? apiBaseUrl, bool? onboardingSeen}) => AppSettings(
        themeMode: themeMode ?? this.themeMode,
        apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
        onboardingSeen: onboardingSeen ?? this.onboardingSeen,
      );
}

class SettingsNotifier extends Notifier<AppSettings> {
  static const _themeKey = 'theme_mode';
  static const _apiKey = 'api_base_url';
  static const _onboardingKey = 'onboarding_seen';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() => AppSettings(
        themeMode: ThemeMode.values.asNameMap()[_prefs.getString(_themeKey)] ?? ThemeMode.system,
        apiBaseUrl: _prefs.getString(_apiKey) ?? Env.apiBaseUrl,
        onboardingSeen: _prefs.getBool(_onboardingKey) ?? false,
      );

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeKey, mode.name);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setApiBaseUrl(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    await _prefs.setString(_apiKey, clean);
    state = state.copyWith(apiBaseUrl: clean);
  }

  Future<void> markOnboardingSeen() async {
    await _prefs.setBool(_onboardingKey, true);
    state = state.copyWith(onboardingSeen: true);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// ---------- Backend ----------

final apiProvider = Provider<MealLensApi>((ref) {
  final auth = ref.watch(authProvider);
  final baseUrl = ref.watch(settingsProvider.select((s) => s.apiBaseUrl));
  return HttpMealLensApi(baseUrl: baseUrl, token: auth.accessToken);
});

// ---------- Fridge ----------

class InventoryNotifier extends AsyncNotifier<List<InventoryItem>> {
  MealLensApi get _api => ref.read(apiProvider);

  @override
  Future<List<InventoryItem>> build() => ref.watch(apiProvider).inventory();

  /// After a confirmed scan the backend returns the whole fridge; show it without refetching.
  void replace(List<InventoryItem> items) => state = AsyncData(items);

  Future<void> add(int ingredientId) async {
    await _api.addToFridge(ingredientId);
    state = AsyncData(await _api.inventory());
  }

  Future<void> setExpiry(InventoryItem item, DateTime? date) async {
    await _api.setExpiry(item.id, date);
    state = AsyncData(await _api.inventory());
  }

  /// Removes at once on screen; puts the item back if the server refuses.
  Future<void> remove(InventoryItem item) async {
    final before = state.value ?? const <InventoryItem>[];
    state = AsyncData([for (final i in before) if (i.id != item.id) i]);
    try {
      await _api.removeItem(item.id);
    } catch (_) {
      state = AsyncData(before);
      rethrow;
    }
  }
}

final inventoryProvider = AsyncNotifierProvider<InventoryNotifier, List<InventoryItem>>(InventoryNotifier.new);
