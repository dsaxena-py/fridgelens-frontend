import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../data/auth.dart';

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
