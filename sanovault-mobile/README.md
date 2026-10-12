# SanoVault Mobile

Flutter client for the SanoVault family folder: a Cupertino app for iOS, Android and macOS that talks to the API in [`../sanovault-web`](../sanovault-web) (default `https://www.sanovault.com`).

Scope, architecture and open work: [PLAN.md](./PLAN.md). Shared design rules (palette, tabs, ordering): [../DESIGN.md](../DESIGN.md). Mac folder import: [../FOLDER-CHECK.md](../FOLDER-CHECK.md).

## What the app does

Home with one card per person; Reports (sorted by document date); a Log tab for symptoms and notes, blood pressure, height and weight, medicines and reports; medicines with photo scan; doctor packet; vaccinations; family sharing; offline cache and queue; share-sheet import from other apps (such as WhatsApp); Folder Check on macOS.

## Version

Current store release in `pubspec.yaml`: **0.0.3+201** (version name `0.0.3`, build number `201`). This sets iOS/macOS bundle version and Android version name/code through Flutter's build configuration.

## Run (debug)

```bash
cd sanovault-mobile
flutter pub get
flutter run                 # pick device
flutter run -d macos
```

Requires Flutter 3.47+ (Dart 3.13+). Sign in with an existing SanoVault account. Email / Google / magic link opens the website inside a system auth session, then returns here. Sign in with Apple needs the `com.sanovault.app` App ID and capability on the Apple Developer team.

To point at a local API:

```bash
flutter run --dart-define=API_URL=http://localhost:3001
```

## Test and analyze

```bash
flutter analyze
flutter test
```

## Source layout

```
lib/api/        HTTP client, models, endpoint wrappers (with the offline cache fallbacks)
lib/session/    Sign-in state, shared people list (PeopleStore), offline store and queue, preferences
lib/theme/      Palette tokens (SvColors) and Cupertino theme
lib/features/   One folder per area: home, reports, log, vitals, tracking, medicines, family, doctor, more, ...
lib/widgets/    Shared controls: person picker, page scaffold, date picker, PeopleAware mixin
ios/ShareExtension/   iOS share-sheet extension
```

## Store release builds

### Android (Play Store AAB)

1. Create an upload keystore (once):

```bash
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias sanovault
```

2. Copy `android/key.properties.example` to `android/key.properties` and fill in passwords / paths. Do not commit `key.properties` or `*.jks`.

3. Build:

```bash
flutter build appbundle --release
# output: build/app/outputs/bundle/release/app-release.aab
```

### iOS (App Store)

1. In Apple Developer: App ID `com.sanovault.app` with Sign in with Apple + App Group `group.com.sanovault.app`.
2. Share Extension App ID `com.sanovault.app.ShareExtension` with the same App Group.
3. Archive / IPA:

```bash
flutter build ipa --release
# output under build/ios/ipa/
```

Or open `ios/Runner.xcworkspace` in Xcode → Product → Archive → Distribute App.

### macOS (Mac App Store)

```bash
flutter build macos --release
# app: build/macos/Build/Products/Release/SanoVault.app
```

Then archive/sign in Xcode (`macos/Runner.xcworkspace`) with the Mac App Store distribution profile for `com.sanovault.app`.
