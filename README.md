# MealLens app

Flutter app for Android and iOS. It follows the MealLens brand guidelines: the Mist & Eucalyptus
and Graphite Mint themes, Nunito Sans (Regular 400 and Medium 500 only), the Plate Focus mark,
soft rounded shapes and calm, reduced-motion-aware animation.

**Built so far (step 1):** native launch screen and app icon, splash screen, three onboarding
pages, and sign-in / create account with Supabase Auth (email and password). After signing in
you land on a placeholder screen; the fridge, scanning and recipes come in the next steps.

## Run it

1. Install Flutter 3.47 (stable) and set up an Android device or emulator, or Xcode for iOS.
2. Copy `config.example.json` to `config.json` and fill in:
   - `SUPABASE_URL`: `https://<project-ref>.supabase.co`
   - `SUPABASE_PUBLISHABLE_KEY`: Supabase dashboard → Project Settings → API Keys. Use the
     publishable key (or the legacy anon key). It is safe in the app; RLS protects the data.
     **Never** put the service-role key here.
   - `API_BASE_URL`: the backend on your laptop, e.g. `http://192.168.1.20:8000` (not used yet).
3. Run:
   ```bash
   flutter pub get
   flutter run --dart-define-from-file=config.json
   ```

`config.json` is git-ignored.

### Email confirmation

Supabase asks new users to confirm their email by default. The app handles that: it tells
people to check their inbox, then sign in. For quicker testing, turn it off in Authentication →
Sign In / Providers → Email → **Confirm email**.

## Project layout

```
lib/
  main.dart, app.dart        start-up: splash while Supabase starts, then the router
  router.dart                signed out → onboarding (first time) or sign-in; signed in → home
  config.dart                build-time settings from config.json
  theme/                     brand tokens (colours, spacing, radii) and the Material theme
  widgets/logo.dart          Plate Focus mark (drawn in code) and the horizontal lockup
  data/auth.dart             Supabase Auth, with friendly error messages
  state/providers.dart       Riverpod providers: settings, auth
  features/                  splash, onboarding, auth, home placeholder
assets/
  google_fonts/              Nunito Sans Regular and Medium, bundled (no runtime downloads)
  brand/                     launch-screen and icon images
tool/
  render_brand_assets_test.dart   renders assets/brand/*.png from the logo painter
  screenshots_test.dart           renders every screen, light and dark, for review
```

## Tests

```bash
flutter analyze
flutter test test/
```

The tests cover start-up (splash, slow start, retry, missing settings), every onboarding path,
form validation, sign-in errors, the email-confirmation path and sign-out. They also check light
and dark mode, and a small phone at 200% text size without overflow.

## Brand assets

The launch screen and app icon come from the same painter as the in-app logo. After changing the
mark:

```bash
flutter test tool/render_brand_assets_test.dart
dart run flutter_native_splash:create
dart run flutter_launcher_icons
```

To look at every screen in both themes: `flutter test tool/screenshots_test.dart --update-goldens`,
then open `tool/screenshots/`.

Nunito Sans is licensed under the SIL Open Font License 1.1.
