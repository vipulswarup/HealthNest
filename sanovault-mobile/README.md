# SanoVault Mobile

Flutter client for the SanoVault family folder. Product plan: [PLAN.md](./PLAN.md).

Cupertino app for iOS, Android, and macOS against `https://www.sanovault.com`.

## Version

Current store release in `pubspec.yaml`: **0.0.1+1** (version name `0.0.1`, build number `1`).

## Run (debug)

```bash
cd sanovault-mobile
flutter pub get
flutter run                 # pick device
flutter run -d macos
```

Sign in with an existing SanoVault account. Email / Google / magic link opens the website inside a system auth session, then returns here. Sign in with Apple needs the `com.sanovault.app` App ID and capability on the Apple Developer team.

To point at a local API:

```bash
flutter run --dart-define=API_URL=http://localhost:3001
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
