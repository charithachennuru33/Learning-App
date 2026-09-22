# Ram Intellect mobile app

Flutter app for Android and iOS. It signs users in with a phone OTP against
[platform-infra](../platform-infra) and keeps them signed in with rotating refresh tokens.

## Structure

```
lib/
  main.dart                       wiring: config → token store → API client → auth
  src/config/                     API_BASE_URL / DEMO_MODE (build-time --dart-define)
  src/api/                        Dio client: bearer token, one shared refresh on 401, error parsing
  src/auth/                       models, secure token store, repository, sign-in state
  src/demo/                       demo backend (auth), demo catalogue + in-memory app state
  src/theme/                      light/dark palettes (logo colours), text styles, ThemeData
  src/widgets/                    bottom-bar shell, course cards, shared UI pieces
  src/features/
    auth/screens/login_screen.dart              phone + OTP on one screen
    home/screens/home_screen.dart               continue watching, domain chips, course rows
    catalog/screens/domains_screen.dart         searchable domain grid
    catalog/screens/domain_screen.dart          courses in one domain
    catalog/screens/course_detail_screen.dart   lessons / about / notes, unlock bar
    player/screens/player_screen.dart           simulated playback, speed, quality, up next
    billing/screens/paywall_screen.dart         plans, coupons, demo purchase
    profile/screens/profile_screen.dart         subscription card, account actions
    learning/screens/my_learning_screen.dart    in progress + saved
    admin/screens/admin_upload_screen.dart      upload form + pipeline queue
    admin/screens/admin_pricing_screen.dart     plans table, coupons, new coupon
  src/router.dart                 go_router: sign-in guard, 4-tab shell, full-screen pages
assets/branding/                  logo (transparent PNGs) and app-icon sources
tool/Unblack.cs                   regenerates the transparent logos from a black-background JPEG
test/                             unit, flow and every-screen render tests (no server needed)
```

Screens follow `ram-intellect-app-screens.html`, using the logo's blue/cyan instead of the reference's orange.
Gold marks Premium. The app starts in the **white theme**; the sun/moon button at the top of the screens
switches to dark (not remembered between launches yet).

Everything behind the screens is local demo data (`DemoState`): subscribing on the paywall unlocks lessons,
prices edited in Admin → Pricing appear on the paywall, uploads move through the simulated pipeline, and
signing out resets the learner. The admin panel opens from Profile → Admin panel. It uses a sidebar at 900 px
and wider (tablet / future Flutter Web build) and a drawer on phones.

Tokens are stored in the iOS Keychain (this device only) and Android encrypted storage.

## Demo mode (no backend needed)

Debug builds start in **demo mode**: a built-in fake backend (`lib/src/demo/demo_backend.dart`) answers the
auth API, so you can try the app without platform-infra, Docker or SMS.

- Any valid Indian mobile number works (e.g. `9876543210`). The OTP is always **`123456`**.
- It follows the real rules: 5 wrong codes burn the OTP, and resends wait 30 s.
- A red **DEMO** ribbon and a notice on the sign-in screens show when it's active.
- Sessions live in memory, so restarting the app signs you out.
- Release builds can never run in demo mode.

```bash
flutter run                              # demo mode (default in debug)
flutter run --dart-define=DEMO_MODE=false   # use the real platform-infra backend
```

## Run against the real backend

Start the backend first (from `../platform-infra`):

```bash
docker compose up -d
mvn spring-boot:run -Dspring-boot.run.profiles=dev
```

Then, from this folder:

```bash
flutter pub get
flutter run --dart-define=DEMO_MODE=false
```

Debug builds default to `http://10.0.2.2:8080` on the Android emulator (the emulator's alias for your PC)
and `http://localhost:8080` on the iOS simulator. The dev backend prints each OTP in its console.

On a **physical phone**, localhost is the phone itself. Put the phone and PC on the same Wi-Fi and pass
the PC's LAN address:

```bash
flutter run --dart-define=DEMO_MODE=false --dart-define=API_BASE_URL=http://192.168.1.50:8080
```

## Tests

```bash
flutter analyze
flutter test
```

## Release builds

A release build refuses to start without an HTTPS API address:

```bash
flutter build appbundle --dart-define=API_BASE_URL=https://api.example.com   # Play Store
flutter build ipa --dart-define=API_BASE_URL=https://api.example.com         # App Store (macOS only)
```

Before publishing: set a release signing key in `android/app/build.gradle.kts` (it currently signs with the
debug key), pick the final application ID (`com.ramintellect.learning_app`), and set up signing in Xcode.

Plain HTTP is allowed only in Android debug builds and, on iOS, only to local-network addresses.

## Icons and logo

App icons are generated from `assets/branding/app_icon.png` (iOS, opaque on black, as Apple requires)
and `app_icon_foreground.png` (Android adaptive icon, transparent on a black background):

```bash
dart run flutter_launcher_icons
```
