/// Build-time configuration, passed with `flutter run --dart-define-from-file=config.json`
/// (see config.example.json).
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  /// Supabase dashboard → Project Settings → API Keys → publishable key (or the legacy anon key).
  /// It is safe to ship in the app; Row Level Security protects the data.
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Default backend address. 10.0.2.2 is the host machine as seen from the Android emulator;
  /// on a real phone use the laptop's Wi-Fi address.
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');

  static bool get configured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
