# SanoVault Mobile: scope, architecture and status

The phone, iPad and Mac experience of SanoVault. The website in `../sanovault-web` is both the desktop experience and the API. This file is the status and roadmap; how to build and release is in [README.md](./README.md); visual and interaction rules are in [../DESIGN.md](../DESIGN.md).

## Principles

1. **Same backend.** No separate mobile service. Base URL defaults to `https://www.sanovault.com`; override with `--dart-define=API_URL=...`.
2. **Bearer-token auth.** The app never uses web cookies. A token comes from Sign in with Apple (`POST /api/auth/mobile/apple`), email and password (`/api/auth/mobile/password`) or the web bridge (`sanovault://auth?token=`). It is kept in secure storage and revoked on sign-out.
3. **Beta acknowledgement first.** No health data is requested before the current terms are accepted.
4. **The server is the source of truth, with an on-device cache.** Lightweight JSON (people, dashboard, records, readings, notes) is cached in secure storage so screens open instantly and work offline for up to 30 days since the last online check. Additions made offline (readings, notes, reports) are queued and sent when the connection returns. The cache and queue are wiped on sign-out.
5. **Parity of flows, not pixels.** Labels and data match the website; layout follows iOS conventions.
6. **Bundle ID** `com.sanovault.app`, share extension `com.sanovault.app.ShareExtension`, App Group `group.com.sanovault.app`.

## Architecture

- Flutter 3.47, Dart 3.13, `CupertinoApp`.
- `http` client with bearer auth; `flutter_secure_storage` for the token and the cache; `shared_preferences` for the last-used person.
- `SessionController` holds sign-in state and owns the shared **`PeopleStore`**. Every screen reads the people list from it (memory, then cache, then network) through the `PeopleAware` mixin, so pickers never wait on a fetch.
- Per-person lists (reports, readings, notes) follow *cache first, refresh in the background*, with a generation counter so a slow response for a previous person is ignored.
- Share sheet: `share_handler` plus the iOS extension open the import screen, which uploads and creates a "needs review" record; the server reads the document in the background.
- Reports can be scanned (`cunning_document_scanner`), picked from photos or files, and viewed with `pdfrx` (PDFKit on Apple platforms).

## Tabs

Home · Reports · Log · Medicines · More. See [../DESIGN.md](../DESIGN.md#navigation) for what each contains and the rules behind it.

## Status

| Area | Status |
| --- | --- |
| Sign-in (Apple, email, web bridge), beta gate, session restore, sign-out | Done |
| Home, households, invites, add person, person profile and edit | Done |
| Reports: list by document date with month headers, search, needs-review filter, detail, document viewer, offline copies | Done |
| Add a report: scan, photos, files; OCR, classify, tag; password-protected PDFs; offline queue | Done |
| Share-sheet import (iOS/Android) | Done; PDFs are unlocked on the server with the person's saved passwords |
| Medicines: list, scan a label, review before saving, mark as stopped | Done |
| Log tab; Symptoms & Notes (edit, delete, backdate, grouped by date); Blood pressure (edit, delete, 7/30/90-day history, average); Height and weight; Vaccinations | Done |
| Doctor packet | Done |
| Privacy controls: AI processing consent, account deletion, privacy policy | Done |
| macOS Folder Check | Done; see [../FOLDER-CHECK.md](../FOLDER-CHECK.md) |
| Teal palette and new navigation | Done, awaiting on-device visual review |
| Apple Health / Health Connect blood-pressure sync (server endpoint exists) | Not started in the app |
| Push notifications (device registration endpoint exists) | Not started in the app |

## Open work

Ordered by value.

1. **On-device review** of the new palette, Log tab, Reports and Symptoms & Notes screens; time the BP and share flows before and after the speed work.
2. **Needs-review inbox**: a count badge on the Reports tab and quick clearing of imported items.
3. **Medicine reminders**: local notifications for doses and refills.
4. **Blood-pressure trends**: chart, plus Apple Health / Health Connect sync.
5. **Editing offline items**: allow changing a note or reading that has not synced yet (today the app asks the person to wait).
6. **Accessibility pass**: explicit screen-reader labels, large-text layouts, contrast audit of every screen.
7. **Dirty-form guard** when switching person mid-entry; consistent loading, empty and error states across the remaining screens.
8. **Consolidate the cache**: it currently uses secure storage for all JSON; a lighter store may be faster for large lists.
9. **Tests**: ordering and models are covered; add widget tests for the Log, Reports and Symptoms screens.
10. **Dependency upgrades**: many packages have newer versions.

## Decisions on record

- Family tab removed; people management lives under More → People and on Home.
- Pinned notes removed; strictly newest first.
- "Add a report" exists only under Reports (and via the share sheet and the Log tab).
- Palette: calm clinical teal (cream and coral retired).
