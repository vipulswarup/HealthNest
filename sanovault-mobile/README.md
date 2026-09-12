# SanoVault Mobile

Flutter client for the SanoVault family folder. Product plan: [PLAN.md](./PLAN.md).

Phase 1 is a Cupertino iOS app: sign-in, beta acknowledgement, and the Family home against `https://www.sanovault.com`.

## Run on iOS

```bash
cd sanovault-mobile
flutter pub get
open -a Simulator
flutter run
```

Sign in with an existing SanoVault account. Email / Google / magic link opens the website inside a system auth session, then returns here. Sign in with Apple needs the `com.sanovault.app` App ID and capability on the Apple Developer team.

To point at a local API:

```bash
flutter run --dart-define=API_URL=http://localhost:3001
```
