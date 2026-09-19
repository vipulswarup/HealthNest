# Flutter UI/UX audit and implementation plan

Date: 19 September 2026  
Status: Proposed; no application code changed.

## Scope and evidence

This is a source-based audit of the Flutter client, focusing on person selection, BP recording/history, medicines, reports, navigation, and shared controls. The web BP API was inspected to establish the data contract. The app was not launched; layout, screen-reader behavior, and perceived performance need device validation. Findings below distinguish observed implementation behavior from proposed design choices.

Paths are relative to `sanovault-mobile/` unless prefixed with `../sanovault-web/`. This document is an implementation backlog, not a replacement for `PLAN.md`.

## Priorities

| ID | Priority | Improvement | Scope |
| --- | --- | --- | --- |
| UX-01 | P1 | Replace the people carousel with an explicit person selector | Shared widget and all consumers |
| UX-02 | P1 | Show every returned BP reading, newest first | Flutter model and BP screen |
| UX-03 | P1, quick win | Replace the Medicines heart with a pill icon | Tab shell |
| UX-04 | P1 | Keep person identity, drafts, and asynchronous results aligned | Shared selection behavior and feature screens |
| UX-05 | P1 | Improve BP entry, validation, and save feedback | BP screen and shared controls |
| UX-06 | P1 | Review medicine details before creating an entry | Medicines screen and a reusable medicine form |
| UX-07 | P2 | Make report filtering and search scope predictable | Reports and Family screens |
| UX-08 | P2 | Distinguish loading, empty, error, and saved states | Shared controls and tracking screens |
| UX-09 | P2 | Clarify navigation and expose report creation where needed | Home, Reports, and More |
| UX-10 | P1 for contrast; P2 for broader polish | Improve contrast, accessible labels, and responsive layout | Theme and shared/feature widgets |

P1 means the first implementation cycle; P2 follows once the core flows are reliable. Ship UX-01 with UX-04 so easier switching also preserves correct person context.

## UX-01 — Replace the people carousel

**Observed:** `lib/widgets/person_picker.dart` renders every name in one horizontally scrolling row. There is no search, no selected-person summary outside the row, and no explicit selected semantics. Long names and larger families require horizontal hunting. Empty data always displays “Add a person on Home first,” including while consumers are still fetching people.

**Proposed interaction:** A full-width row reading `Person · [full name]` with a “Change” affordance opens a Cupertino modal sheet. The sheet contains a search field, vertically scrolling person rows, a checkmark for the selected person, and Cancel. Use available distinguishing profile details for duplicate names; do not fabricate relationship labels. Allow names to wrap.

Implementation:

1. Keep the existing `people`, `selectedId`, and `onSelected` contract where practical; add explicit loading/disabled and empty-state handling. Keep API requests outside the selector.
2. Use a searchable vertical list for multiple people. For one person, show the same identity row without an unnecessary chooser. For zero people after loading, provide an actionable route to the existing add-person/folder flow.
3. Preserve list order while searching; opening the sheet should make the current selection easy to find. Search should ignore case and surrounding whitespace.
4. Give the trigger an accessible label such as “Person, Anika Rao, change person”; mark selected rows semantically, not just by color. Return focus to the trigger on dismissal.
5. Update all ten consumers: BP, Growth, Medicines, Reports, Add Report, Share Import, Vaccinations, Visit Notes, Doctor, and macOS Folder Check. Adapt the sheet to a bounded width on macOS.

**Acceptance:** With 1, 2, and 12 people, long/duplicate names, and large text, the chosen person is obvious without horizontal scrolling. Search and cancel preserve the selection correctly. Loading never looks like an empty family. Choosing a visible person takes two taps; choosing the current person does not reload data.

## UX-02 — BP readings newest first

**Observed:** `lib/features/vitals/bp_page.dart` renders `BloodPressureWeek.lines`. In `../sanovault-web/lib/vitals/blood-pressure.ts`, these lines traverse dates oldest first and include only the latest morning/afternoon/evening reading per day. Readings classified as `other` are omitted. In contrast, `../sanovault-web/lib/services/blood-pressure.service.ts` already returns raw `readings` ordered by `recorded_at DESC`. The Flutter model retains these as maps but does not use them in the UI.

Implementation:

1. Add a typed `BloodPressureReading` in `lib/api/models.dart` with ID, patient ID, recorded timestamp, systolic, diastolic, optional pulse, and relevant source/period fields. Parse timestamps defensively.
2. Render `readings`, sorted by parsed timestamp descending, with a deterministic ID tie-breaker. Do not reverse or parse the human-readable `lines` strings. Preserve the existing summary contract for the doctor packet.
3. Show each reading as a readable row: prominent `120 / 80 mmHg`, then date/time and optional `Pulse 72 bpm`. Preserve multiple readings in the same period and overnight readings. Mark the first valid chronological row “Latest.”
4. Use device-local date/time consistently for display and compare absolute timestamps for sorting. Do not combine device-local times with the server's India-specific period labels. Label the time-zone basis if needed when sharing/exporting later.
5. Replace “This week” with “Recent readings” and disclose the current limited history window: the raw endpoint queries the preceding eight days, while summary lines cover seven calendar dates. Do not imply that all history is available. Longer history and pagination are separate backend work.
6. Use the POST response's updated readings after a successful save, or refresh safely. A new current-time reading must appear at the top immediately. An invalid timestamp must not crash sorting or be labeled “Latest”; show “Time unavailable” after dated records.

**Files:** `lib/api/models.dart`, `lib/features/vitals/bp_page.dart`, `lib/util/dates.dart`; adjust `lib/api/sanovault_api.dart` only if model integration requires it.

**Acceptance:** Unsorted fixtures display newest first, including multiple same-day/same-period readings, overnight readings, different UTC offsets, equal timestamps, and missing pulse. A new save is visible first. No backend ordering or summary changes are required for this fix.

## UX-03 — Medicines tab icon

**Observed:** `lib/features/shell/tab_shell.dart` uses `CupertinoIcons.heart` for “Medicines.”

Replace it with a pill/capsule symbol, preferably `CupertinoIcons.capsule` and a filled selected variant if supported by the installed Flutter SDK. Verify symbol availability during implementation; preserve the visible “Medicines” label and tab position. Check visual weight alongside the other tab icons. No new image asset or dependency should be needed.

**Acceptance:** The Medicines tab shows a recognizable pill at normal and enlarged display settings. Tab navigation and accessible naming remain intact. This needs a visual check, not a dedicated test that merely asserts an icon constant.

## UX-04 — Make person switching reliable

**Observed:** BP, Growth, Vaccinations, and Visit Notes retain their text controllers when the selected person changes. Several pages change `_patientId` immediately but retain the old person's content until fetching completes. Load methods lack stale-response guards. `rememberPerson()` also invalidates global data while several callers explicitly call `_load()`, allowing redundant requests. Long-running medicine extraction reads the mutable `_patientId` when creating the entry.

Implementation:

1. Capture the requested person ID and a request generation for each load; apply results only when both still match. Immediately replace the previous person's content with a loading state when switching people. For refresh of the same person, existing content may remain with a refresh indicator.
2. Keep selected-person state distinct from persisted “last used” preference. On entry, use a valid explicit route person first, then a valid remembered person, then the first accessible person. Revalidate against the current household after household/access changes.
3. Keep open screens' selection explicit; a preference update elsewhere should not silently retarget an in-progress form. Clear or namespace remembered preferences across accounts/households as appropriate.
4. When a form is dirty, show “Discard this entry and change person?” with Cancel and Discard. Never carry readings, medicine drafts, or uploaded report associations silently to another person. For uploaded documents, inspect ownership/assignment APIs before allowing reassignment.
5. Capture person ID and input values at the start of each mutation. Disable person switching during save/import; retain the captured person through photo extraction and review. Add mounted checks before post-await UI/context access.
6. Separate remembering a selection from broadcasting data mutations. Ensure a single intended load per selection and explicitly invalidate relevant lists after successful writes.

**Files:** `lib/widgets/person_picker.dart`, `lib/session/app_preferences.dart`, relevant session invalidation code, and the selector consumers listed in UX-01.

**Acceptance:** Switch A → B quickly while A's response is delayed: only B's data appears under B. Failed B loads never show A's data as B's. Canceling a dirty-form switch preserves A and the draft. Saving or extracting for A cannot create an entry for B. A household change cannot leave an inaccessible selection active.

## UX-05 — Make BP entry clear and dependable

**Observed:** BP fields have placeholders only; units disappear from view because they are not supplied. Validation checks only that systolic/diastolic parse as integers. Invalid non-empty pulse becomes null. Save is always enabled, with no in-flight guard or explicit success state.

Implementation:

1. Add persistent labels: “Systolic (mmHg),” “Diastolic (mmHg),” and “Pulse (bpm, optional).” Keep examples in placeholders, and show “Recording for [name]” above the form.
2. Provide Next/Done focus behavior and a keyboard-dismiss action on numeric keyboards; ensure the save button and active field remain reachable with the keyboard open.
3. Mirror the existing API input constraints with field-level messages: systolic integer 50–250, diastolic integer 30–180, pulse integer 20–220 when supplied, and diastolic below systolic. These are existing storage/API limits, not diagnostic guidance or newly proposed clinical thresholds.
4. Add a synchronous save guard and “Saving…” state; disable repeat submission. Keep entered values on failure, focus the first invalid field, and clear only after confirmed success.
5. Show “Reading saved for [name]” and expose the new reading. Distinguish a confirmed save followed by refresh failure from a failed save so users do not create duplicates. Do not automatically retry a POST after an ambiguous network failure.

**Files:** `lib/features/vitals/bp_page.dart`, `lib/widgets/sv_controls.dart`; the API constraints are in `../sanovault-web/app/api/vitals/blood-pressure/route.ts`.

**Acceptance:** Invalid non-empty pulse cannot silently disappear; repeated taps send one request; failed saves retain the draft; success updates history and gives visible/accessibility feedback. No diagnostic colors or new medical classifications are part of this scope.

## UX-06 — Review medicine entries before saving

**Observed:** `_createFromExtract()` creates a medicine immediately after photo extraction, defaulting missing frequency to `daily` and route to `oral`. Manual entry exposes only name and dosage and dismisses before its request completes. `_stop()` immediately changes medication status. Manual-save and stop errors lack local recovery handling.

Implementation:

1. Route both photo and manual entry through one editable form. Show the intended person, medicine name, dosage, frequency, route, and start date. Check the existing create/update contract before deciding which fields may remain unknown.
2. Prefill extracted values for review and visibly distinguish missing values. Require explicit review of required fields; do not silently invent a daily schedule or route for an unreadable photo.
3. Keep the form open on validation/network failure, preserve input, and show saving/extraction progress. Prevent duplicate photo jobs and submissions. Dispose form controllers with the form lifecycle.
4. Rename “Photo” to “Scan medicine” and “Add” to “Add manually,” adapting to a stacked layout when space is limited.
5. Rename the list action to “Mark as stopped” and confirm the named medicine before updating its recorded status. Explain that this updates the list. Keep the entry unchanged on API failure and show a retryable error.
6. Allow multi-line medicine details so long names/dosage instructions remain readable.

**Files:** `lib/features/medicines/medicines_page.dart`; proposed `lib/features/medicines/medicine_form_page.dart`; existing medication API/model code as needed.

**Acceptance:** Extraction alone never creates an entry; cancel creates nothing; the chosen person's identity stays fixed through extraction/review/save. Validation errors retain input. Failed “Mark as stopped” operations leave the visible active list correct.

## UX-07 — Predictable report scope and search

**Observed:** Reports search only runs on submit. Clearing the search field does not update `_query` through an `onChanged` handler. Enabling “Needs review” sends `patientId: null` while the selector still displays one selected person. Family search shows “No people in this folder yet” even when people exist but the query has no matches.

Implementation:

- Keep “Needs review” scoped to the selected person by retaining the patient filter. If a household-wide review inbox is later desired, give it an explicit “All people” scope and identify the person on every result.
- Use a short debounce for Reports search, immediate reset on clear, and the stale-response protection from UX-04. Keep keyboard Submit as an immediate search action.
- Distinguish “No reports for [name] yet” from “No matching reports”; offer Add report in the former and Clear filters in the latter. Make the equivalent distinction in Family search.

**Files:** `lib/features/reports/reports_page.dart`, `lib/features/family/family_page.dart`.

**Acceptance:** Clear restores the unfiltered list; delayed searches cannot overwrite newer results; selected-person and “Needs review” filters compose without silently widening scope.

## UX-08 — Consistent progress and recovery

**Observed:** BP, Growth, Vaccinations, and Visit Notes initially render empty-state text while requests are pending. Shared errors have no Retry action. Several pages display `caught.toString()`. More suppresses household-load failures. Growth can submit null measurements after failed parsing; Vaccinations silently returns for an empty name.

Implementation:

- Standardize initial loading, loaded-empty, loaded-content, and failed states; show “No readings yet” only after a successful empty response.
- Extend shared controls with busy buttons, concise recoverable errors, optional Retry, and accessible status announcements. Preserve useful same-person data during refresh failures.
- Reuse the BP form behavior for Growth, Vaccinations, and Visit Notes: persistent labels, visible required-field messages, preserved drafts, and save guards. Growth needs decimal-capable input and field validation against its API contract.
- Make household switch/load failure visible in More, retain the prior active household after failed changes, and prevent overlapping switch requests.

**Acceptance:** Slow networks show progress; no-person and failed-load states are distinguishable; retries work; no silent no-op on an invalid submission; empty and malformed measurement input never appears successfully saved.

## UX-09 — Navigation and discoverability

**Observed:** Home's large title is “Family” or “Family, [name]” while a separate Family tab also exists. Reports has no direct Add report action. More mixes tracking, sharing, household management, and account actions.

Implementation:

- Title the Home landing screen “Home” (place any greeting in body copy), retaining Family for person management. Preserve existing BP/report shortcuts on Home and person detail pages.
- Add an “Add report” navigation action on Reports, passing its selected person into `AddReportPage`. Reload/invalidate Reports on successful return.
- Group More into clear sections such as Health tracking, Sharing and access, and Account. Preserve route destinations and the existing five tabs.

**Acceptance:** Users can add a report directly from Reports without changing tabs, with the correct person preselected. Home and Family have distinct titles and purposes. Validate section wording with a short walkthrough before further navigation restructuring.

## UX-10 — Accessibility and layout

**Observed:** Shared buttons and selected person chips use white text on coral `#EF8354`; the calculated contrast ratio is approximately 2.61:1. The theme is explicitly light. Fixed Rows and single-line list tiles warrant device checks; clipping has not been confirmed by running the app.

Implementation:

- Introduce a tested foreground/background pair for primary controls and text links. Use a project target of at least 4.5:1 for ordinary text; preserve coral as an accent where readable. Audit selected, disabled, and pressed states separately.
- Set a minimum 48 logical-pixel interactive area for new controls, keep adequate spacing, and use text/checkmarks as well as color for selection.
- Ensure long names, medicine directions, BP metadata, and action labels wrap or adapt at 200% text scale. Prefer vertical form layouts on narrow screens.
- Add meaningful field labels, selected states, and progress/error announcements; check focus order, VoiceOver, TalkBack, keyboard navigation, and modal dismissal.
- Keep dark mode as a separate follow-up unless it becomes an explicit requirement; test the current light presentation in both OS appearance settings.

**Files:** `lib/theme/sv_colors.dart`, `lib/theme/sv_theme.dart`, `lib/widgets/sv_controls.dart`, `lib/widgets/person_picker.dart`, affected feature layouts.

## Assessment of the supplied web tips

The supplied animation, imagery, and accessibility tips and the pasted article “Best Practices for Responsive Design in Flutter: Building Apps That Work Everywhere” are inputs for consideration, not implementation requirements. The decisions below apply them to SanoVault's recording and retrieval flows. Technical guidance was cross-checked against Flutter's official documentation; the article's marketing claims and performance claims are not treated as evidence.

| Advice | Decision | Application to SanoVault |
| --- | --- | --- |
| Animations and transitions | Adopt selectively; P2 polish | Keep existing route/sheet transitions. Consider a brief fade for saved feedback if it helps users notice completion. Never delay saving, input, or navigation for an animation. |
| Images and icons | Adopt relevance and restraint | Use the pill icon from UX-03 and consistent action icons with labels. Keep report/medicine images where they help identify actual content. Skip decorative stock photos, animated hearts, and illustrations added merely to fill empty states. |
| Accessibility | Adopt as acceptance criteria | Contrast, scalable text, persistent labels, meaningful semantics, adequate touch targets, and keyboard/screen-reader checks are part of UX-01/05/10, not optional visual polish. |
| Flexible, mobile-first layouts | Adopt | Stack controls on narrow widths and constrain form/sheet width on large windows. Preserve the person, draft, and scroll context across layout changes. |
| Fixed 600/1200 breakpoints and separate device layouts | Adapt; defer broad redesign | Choose layout changes based on the space the content needs. Do not create three separate screen implementations or a new desktop navigation system just because a width threshold is crossed. |
| Grids and additional layout packages | Defer | BP history, medicines, and person selection benefit from readable vertical lists. Introduce a grid only for a demonstrated content need; no new responsive-layout package is justified now. |
| Automatic performance tweaks everywhere | Skip as a blanket rule | Profile a real issue before adding caching, keep-alives, repaint boundaries, or animation packages. Use lazy lists when list size warrants them. |

### Motion rules

Use motion to explain a state change, with approximately 150–200 ms as an initial design choice for optional custom feedback, subject to device review. Keep readable “Saved” text available long enough to notice and announce it accessibly. Success must follow a confirmed save. Do not animate an old person's records into the newly selected person's view or make every history row slide into place.

Honor the OS request to reduce/disable animation: remove nonessential custom movement and show the same information immediately. Review built-in route/sheet behavior on devices as well. Flutter exposes this preference through `MediaQueryData.disableAnimations`. [Flutter animation preference](https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html)

**Acceptance:** Reduced-motion mode preserves all feedback and functionality; no flashing, pulsing decoration, auto-advancing carousels, or artificial waiting is introduced. Optional animation must not move the active input or reset focus.

### Image and icon rules

Prefer the existing icon set for interface symbols. Give icon-only actions a meaningful accessible name; avoid duplicate announcements when adjacent text already labels the control. Provide meaningful labels for informative images and exclude purely decorative images from screen-reader traversal. A generic image description must not substitute for actual medicine details or report text.

For any new content thumbnails, size decoding to the displayed preview and provide loading/failure states. Preserve the original document/image for detailed inspection; do not reduce source quality merely to make a list thumbnail cheaper. Do not add image assets as a prerequisite for the core fixes.

### Responsive advice to correct or ignore

- **Use available width rather than orientation or device identity.** Prefer local constraints for a component's layout. Keep forms and sheets comfortably bounded on wider windows, and support resizing and rotation. Do not copy the article's orientation lock inside `build()`. These decisions follow [Flutter adaptive-design guidance](https://docs.flutter.dev/ui/adaptive-responsive/best-practices).
- **Do not cache screen metrics as a blanket optimization.** Read the specific changing property needed, such as `MediaQuery.sizeOf(context)`, from an appropriate descendant context. This scopes rebuilds and keeps layout responsive to changes; the article's top-level caching claim does not establish a performance benefit. [Flutter MediaQuery documentation](https://api.flutter.dev/flutter/widgets/MediaQuery-class.html)
- **Do not shrink important text to hide overflow.** Skip `FittedBox` for names, readings, and medicine instructions. Prefer wrapping, vertical rearrangement, and accessible scrolling. Ellipsis truncates text; the article's ellipsis example does not guarantee full readable content. Do not restore horizontal scrolling for the person selector as an overflow workaround.
- **Keep-alive is not a rebuild blocker.** It preserves state for eligible offscreen list children. Add it only where that lifecycle behavior is needed; do not use it as a generic fix for expensive builds. [Flutter keep-alive documentation](https://api.flutter.dev/flutter/widgets/AutomaticKeepAliveClientMixin-mixin.html)

**Implementation placement:** Apply accessible labels and relevant icons within their feature batches. Add constrained-width/wrapping behavior to the shared selector and forms in batches 2–4, then review optional motion and wider-window polish in batch 5. These tips do not expand the plan into a visual rebrand or a platform-widget rewrite.

## Coding sequence and verification

| Batch | Work | Dependencies and verification |
| --- | --- | --- |
| 1 | Medicines icon; typed BP records and newest-first history | Independent, small changes. Unit-test parsing/order and manually inspect icon/history. |
| 2 | Person selector plus safe switching | Implement shared selection/request rules together; migrate all consumers. Widget-test search, selection, empty/loading states, and delayed response ordering. |
| 3 | BP form, shared busy/error behavior, contrast | Reuse selection rules. Test validation, duplicate taps, preserved drafts, and confirmed-save/refresh-failure distinction. |
| 4 | Medicine review form and recorded-status confirmation | Reuse busy/error controls and captured-person behavior. Test cancel, extraction-to-review, failed save, and failed status update. |
| 5 | Reports search/scope, tracking consistency, navigation polish | Reuse request guards and state patterns. Test clear/debounce/filter composition; perform platform walkthroughs. |

The current `test/widget_test.dart` contains only a label utility test. Add focused tests around the behavioral risks above, with a fake/injectable API seam as needed. Avoid building a broad state-management rewrite or tests that only mirror widget constants.

For each coding batch, run `flutter analyze` and relevant `flutter test` coverage from `sanovault-mobile/`, followed by checks on iOS and Android. Because the shared selector also serves macOS Folder Check, include a macOS selector/import regression check. Use synthetic fixture data and a local/test backend for mutations.

Manual release checks:

- Small phone and larger device; standard and 200% text; numeric keyboard open; portrait/landscape where supported.
- Empty household, one person, twelve people, long/duplicate names, removed person, household change, and a second signed-in account.
- Slow and failed requests, rapid person changes, repeat taps, route dismissal during a request, and returning from Add Report.
- BP midnight/time-zone boundaries and repeated readings; optional pulse; medication extraction with missing fields.
- VoiceOver/TalkBack identity, field labels, selected state, focus return, and success/error announcements.
- Reduced-motion settings; informative/decorative image semantics; thumbnail failure states if thumbnails are added.
- Tablet split view and macOS window resizing; verify that layout changes retain the person, draft, keyboard focus where appropriate, and scroll context.

## Scope boundaries

The three requested improvements can use existing APIs. Longer BP history/pagination, editable BP recording time, charts, reminders, and diagnostic interpretation are separate features. The existing BP POST schema does not expose `recordedAt`, so a historical-time picker must not be added as a frontend-only change. Any medication fields that the current API cannot represent need a small, separately specified contract change before UI implementation.

The implementation is complete when the three requested issues are resolved, person context remains correct throughout asynchronous operations, the relevant acceptance checks pass, and device validation confirms readable and accessible interactions. No application code, dependencies, or backend behavior were modified during this audit.
