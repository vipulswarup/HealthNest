# SanoVault Flutter App Plan

A native iOS-first Flutter client with the same product surface as `sanovault-web`. The web app remains the API and the desktop experience. This app is the phone and iPad experience.

## Assumptions

These are explicit so later phases do not reopen settled decisions.

1. **iOS first.** The family is on Apple devices. Android is scaffolded by Flutter but not polished until the iOS app covers the web product.
2. **Same backend.** The app talks to the existing Next.js API. Default base URL is `https://www.sanovault.com`. Local development can override with `--dart-define=API_URL=http://localhost:3001`.
3. **No new backend for Phase 1.** Mobile session, Sign in with Apple, bearer auth, dashboard, households, patients, and beta acknowledgement already exist.
4. **Auth model.** The native app never relies on web cookies. It stores a bearer token from `POST /api/auth/mobile/apple` or from the web native-bridge (`sanovault://auth?token=`).
5. **Bundle ID** stays `com.sanovault.app`. That is already the Apple token audience on the server.
6. **Apple look.** Cupertino widgets, large titles, grouped lists, system navigation, tab bar. SanoVault coral (`#EF8354`) is the accent. Typography is San Francisco (system). Light mode first.
7. **API is source of truth.** No local health-record database. Secure storage holds the session token only. Last-used person is a local preference.
8. **Parity means product flows, not pixel copies of the website.** Labels, data, and actions match the web. Layout follows iOS Human Interface Guidelines.
9. **HealthKit, share extension, and push wait.** The previous React Native attempt mixed too many native extras into v1. Those return after core flows work.
10. **Beta acknowledgement is mandatory** before any health-data API, matching `getCurrentUser()` on the server.

## Product surface to match

| Web route | What it does |
|---|---|
| `/auth/signin`, `/auth/signup` | Email, password, magic link, Google. Native also has Sign in with Apple. |
| `/beta-acknowledgement` | Required legal gate |
| `/dashboard` | Family home: people, recent files, invites, empty states |
| `/patients` | Family member profiles |
| `/health-records` | Reports list, detail, document view |
| `/health-records/new` | Capture, OCR, classify, save |
| `/medications` | Active and past medicines, photo extract, printable report |
| `/for-the-doctor` | One-screen doctor packet and share |
| `/bp`, `/growth` | Blood pressure and height/weight |
| `/vaccinations`, `/visit-notes` | Tracking lists |
| `/households` | Who can see this: create, invite, switch |
| `/reports/blood-summary` | Lab comparison |

## Architecture

```
sanovault-mobile/
  lib/
    api/           HTTP client, models, endpoint wrappers
    session/       Token storage and auth state
    theme/         Cupertino colors, text, buttons
    features/      One folder per product area
    widgets/       Shared Cupertino controls
```

- Flutter 3.47, Dart 3.13, `CupertinoApp`.
- `http` for API calls with `Authorization: Bearer`.
- `flutter_secure_storage` for the session token.
- `sign_in_with_apple` for native Apple sign-in.
- `flutter_web_auth_2` for email / Google / magic-link via `/auth/signin?native=1`.
- URL scheme `sanovault://` (already used by `app/auth/native-bridge`).

Tab bar (five items, iOS standard):

1. Home
2. Family
3. Reports
4. Medicines
5. More (For the Doctor, Who Can See This, account)

Primary capture ("Add a Report") is a Home / person-card action, not a fifth competing tab. That matches the web home, not the web's cramped bottom bar.

---

## Phase 1 — Foundation and Family Home

**Status: implemented. Ready to test on the iOS Simulator or a device.**

**Goal:** A signed-in family member can open the iOS app, pass the beta gate, and see the same family home the website shows.

**In this phase**

- Flutter project, bundle ID `com.sanovault.app`, Cupertino theme
- Sign in with Apple
- Email / Google / magic link through the existing web native-bridge
- Secure token storage, restore session on launch, sign out (revoke token)
- Beta acknowledgement screen
- Home: households empty state, pending invites, person cards, recent files
- Create a household, accept an invite, add a person (minimum fields)
- Household switcher
- Tab shell with later tabs as honest placeholders

**Out of this phase**

- Report capture / OCR / document viewer
- Medicines, doctor packet, BP, growth, vaccines, visit notes
- HealthKit, push, share extension
- Android visual polish

**Test**

Install on the iOS Simulator or a device, sign in with an existing SanoVault account, confirm Home matches the website for that household, add a person, sign out, sign back in.

---

## Phase 2 — Family profiles

**Goal:** Full person records, not just the home cards.

- Family tab: list, search, person detail
- Edit person (name, DOB, gender, blood group, ABHA, contacts, hospital IDs)
- Last-used person preference shared with Home
- Empty and error states in the same Cupertino language as Home

APIs: `GET/POST /api/patients`, `GET/PUT/DELETE /api/patients/:id`

---

## Phase 3 — Reports browse

**Goal:** Read the vault the way the website does.

- Reports tab: filter by person, type, keyword, date
- Record detail (type, source, doctor, tags, extracted data)
- Document preview and download via existing file/preview routes
- Deep link from Home recent files

APIs: `GET /api/health-records`, `GET /api/health-records/:id`, document view/file/preview routes

---

## Phase 4 — Add a Report

**Goal:** The capture path that makes the app worth installing.

- Camera, photo library, and files
- Upload to `POST /api/documents/upload`
- OCR (`/api/ocr/process`) and AI classify / tag / source match
- Review screen, then `POST /api/health-records`
- Multi-file queue, matching the web add-report flow
- Page-limit and file-type rules enforced client-side before upload

This is the largest product phase. Keep it on iOS until the flow is boringly reliable.

---

## Phase 5 — Medicines

**Goal:** Active list, add/edit, photo-from-label, printable report.

- Medicines tab scoped to a person
- Add / edit / stop, composition lookup via catalogue search
- Photo extract (`POST /api/medications/extract-from-photo`)
- Share / print medication report

APIs: `/api/medications`, `/api/medication-catalog/search`, `/api/reports/medications`

---

## Phase 6 — For the Doctor

**Goal:** One screen a family member can hand to a clinician.

- Person picker
- Packet from `GET /api/reports/doctor-packet`
- Native share sheet (and WhatsApp when installed)
- Blood-summary route as a secondary lab view

---

## Phase 7 — Vitals

**Goal:** BP and growth without leaving the app.

- Log BP, week view
- Height and weight history
- Bidirectional Apple Health in a follow-up slice inside this phase, after manual logging works
- Vault wins on conflicts (same rule as the earlier native plan)

APIs: `/api/vitals/blood-pressure`, `/api/vitals/blood-pressure/sync`, `/api/vitals/growth`

---

## Phase 8 — Tracking and household admin

**Goal:** Close remaining web parity.

- Vaccinations
- Visit notes
- Who Can See This: members, invites, leave, switch
- Invite create/share from the phone

---

## Phase 9 — Native extras and store

**Goal:** Behave like an iOS app, not a website in a wrapper.

- APNs via existing `POST /api/devices`
- iOS Share Extension into Add a Report
- HealthKit (if not finished in Phase 7)
- App Store assets, TestFlight, Android visual pass
- Offline-tolerant queues only if capture still fails on poor networks

---

## Phase 1 implementation notes

Auth sequence:

1. Launch. If a token exists, `GET /api/users/beta-acknowledgement`.
2. 401: clear token, show Sign In.
3. Not acknowledged: beta screen, then `POST /api/users/beta-acknowledgement`.
4. Acknowledged: `GET /api/dashboard` and `GET /api/users/me`.

Sign in:

- Apple: identity token to `POST /api/auth/mobile/apple`.
- Other methods: `ASWebAuthenticationSession` to `/auth/signin?native=1`, callback `sanovault://auth?token=`.

Home data comes only from `GET /api/dashboard`. Switching household uses `PATCH /api/me/active-household`, then reload dashboard.

Minimum add-person fields match the website: first name, last name, date of birth, gender, household id.
