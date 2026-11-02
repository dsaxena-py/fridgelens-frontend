# MealLens app

Flutter app for Android and iOS. It follows the MealLens brand guidelines: the Mist & Eucalyptus
and Graphite Mint themes, Nunito Sans (Regular 400 and Medium 500 only), the Plate Focus mark,
soft rounded shapes and calm, reduced-motion-aware animation.

**Built so far:**

- **Step 1:** native launch screen and app icon, splash screen, three onboarding pages, and
  sign-in / create account with Supabase Auth (email and password).
- **Step 2:** the fridge (use-soon items first, labelled freshness, add by hand, best-before
  dates, swipe to remove with undo), scanning (camera with corner markers, or a gallery photo),
  the review screen (boxes on the photo; confirm, change or remove each item; uncertain items
  ask a question that must be answered; add what was missed), and Settings (server address
  with a connection test, appearance, sign out).
- **Step 3:** recipes. A bottom bar switches between Fridge and Recipes. Recipes has three
  views: **For your fridge** (ranked by ingredient match, with what is missing), **Browse**
  (search and meal-type filters) and **Saved**. The recipe detail shows a "you have X of Y"
  indicator, ingredients marked in-fridge / missing / pantry staple, estimated nutrition per
  serving and steps, with save and **I cooked this** (optional rating, optionally taking the
  main ingredients out of the fridge). A confirmed scan offers a "See recipes" link.

## Run it

1. Install Flutter 3.47 (stable) and set up an Android device or emulator, or Xcode for iOS.
2. Copy `config.example.json` to `config.json` and fill in:
   - `SUPABASE_URL`: `https://<project-ref>.supabase.co`
   - `SUPABASE_PUBLISHABLE_KEY`: Supabase dashboard → Project Settings → API Keys. Use the
     publishable key (or the legacy anon key). It is safe in the app; RLS protects the data.
     **Never** put the service-role key here.
   - `API_BASE_URL`: the backend on your laptop, e.g. `http://192.168.1.20:8000`. You can also
     change it in the app under Settings, which is easier when the laptop's address changes.
3. Run:
   ```bash
   flutter pub get
   flutter run --dart-define-from-file=config.json
   ```

`config.json` is git-ignored.

### Talking to the backend on your laptop

1. Start the backend with `--host 0.0.0.0` (see the backend README).
2. Put the phone and laptop on the same Wi-Fi network.
3. In the app, open Settings (the sliders icon on the fridge screen), enter
   `http://<laptop address>:8000` and tap **Save and test connection**.

The app is allowed to use plain `http` for this: `usesCleartextTraffic` on Android, and
`NSAllowsArbitraryLoads` on iOS. Both are development settings to remove before a store release.
On the Android emulator the laptop is `http://10.0.2.2:8000`. The emulator has no real camera,
so use **Gallery** there.

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
  state/providers.dart       Riverpod providers: settings, auth, backend, fridge
  data/api.dart              backend client with friendly error messages
  features/                  splash, onboarding, auth, fridge, scan (camera, review), recipes, settings
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

The widget tests use a fake backend and camera. They cover:

- **Step 1:** start-up (splash, slow start, retry, missing settings), every onboarding path,
  form validation, sign-in errors, the email-confirmation path and sign-out.
- **Step 2:** the empty and filled fridge, adding by hand, removing with undo, and the full scan
  review (yes/no on uncertain items, changing, removing, adding missed items, and exactly what
  is sent to the backend). Also nothing found, a failed scan, an upload error, and the server
  address check.
- **Step 3:** empty and no-match states, ranking and match wording, the recipe detail (match
  summary, ingredients, nutrition, steps), save and unsave, cooking with and without taking
  ingredients out, browse filters and search, and matches updating when the fridge changes.

They also check light and dark mode and large text on a small phone.

### Contract test

`test/contract/` runs the app's real HTTP client against a running backend: search, upload a
photo, confirm, the 409 on a second confirm, add, set and clear a best-before date, remove,
recommendations, browsing, recipe detail, save and unsave, "I cooked this", and an invalid token.
It also checks that the app's "you have X of Y" count agrees with the server's match score. It is skipped unless these are set:

```bash
MEALLENS_API_URL=http://127.0.0.1:8000 MEALLENS_TOKEN=<a Supabase access token> \
MEALLENS_PHOTO=path/to/fridge.jpg flutter test test/contract
```

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
