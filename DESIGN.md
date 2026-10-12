# Design and interaction rules

Decisions shared by the website and the mobile app. If a screen disagrees with this file, the screen is wrong (or this file needs updating in the same change).

Tokens live in code: web in `sanovault-web/app/globals.css`, mobile in `sanovault-mobile/lib/theme/sv_colors.dart`. Keep the two in sync.

## Palette: calm clinical teal

| Token | Hex | Use |
| --- | --- | --- |
| brand | `#0F766E` | Primary buttons, links, selected tab, focus ring |
| brand-strong | `#115E59` | Pressed/hover state, text on tinted surfaces |
| brand-tint | `#E3F2F0` | Selected rows, chips, secondary button fill, hover |
| ink | `#1B2B2A` | Body text |
| slate | `#52645F` | Secondary text, inactive icons |
| silver | `#D9E2E1` | Dividers and borders |
| background | `#F5F8F8` | Page background (cool off-white, never cream) |
| surface | `#FFFFFF` | Cards, sheets, bars |
| danger | `#C62828` | Errors, destructive actions, readings flagged high |
| warning / warning-tint | `#7A5200` / `#FFF1CC` | "Needs review" badges |
| success | `#1B7F4B` | Saved confirmations |

On the website, the Tailwind `gray`, `slate`, `blue` and `indigo` scales are remapped to this palette in `globals.css`, so existing utility classes follow the brand. Prefer the named tokens (`bg-brand`, `text-ink`) in new code, and do not introduce new hard-coded hex colours.

## Navigation

Mobile tabs, in order: **Home · Reports · Log · Medicines · More**.

- **Home**: one card per person with *Log Symptom* and *Log BP*, recent reports, invites. *Prepare doctor packet* is a quiet text link, not a primary button.
- **Reports**: the one place to add a report (the "+" in the title bar) and to browse them. The phone share sheet also files reports.
- **Log**: quick entry for a symptom or note, blood pressure, height and weight, a medicine, or a report.
- **More**: people, families and sharing, blood pressure, height and weight, vaccinations, symptoms and notes, doctor packet, privacy, AI processing, account.

The website mirrors this: bottom bar Home · Reports · Log · Medicines on narrow screens, with the full list in the menu.

Rules:

1. **Symptom logging is never more than one tap from Home or the tab bar.**
2. **No per-person "Add a report" buttons.** Reports are added from the Reports area only.
3. The doctor packet is important but occasional; it must not compete with logging.
4. Folder Check (Mac) is the only Mac-specific entry and lives under More.

## Lists and ordering

- **Reports**: newest *document* date first (upload date only when the document has none). Mobile groups by month.
- **Symptoms and notes**: newest first by note date, then by time added, grouped under date headers. No pinning.
- **Blood pressure**: newest reading first, with the latest marked.
- Logged items (symptom notes, blood-pressure readings) can be **edited and deleted**. Items saved offline cannot be changed until they have synced, and the app says so.

## Speed and offline behaviour

- A form must be usable immediately. Never block an entry form on a list fetch.
- Lists show the on-device cache first, then refresh quietly; show a spinner only when there is nothing cached.
- The people list is shared by every screen (one in-memory store, cache first), not fetched per screen.
- Background work (prefetching records, downloading files) waits so it never competes with what the person just tapped.
- Server work done on behalf of a share or upload is asynchronous; the app confirms as soon as the file is stored.

## Content

- Labels are plain and family-friendly: "Symptoms & Notes", "Doctor packet", "Who Can See This".
- Validation messages state the allowed range (for example blood pressure systolic 50–250 mmHg). High readings are coloured, not diagnosed.
- Medical terms and extracted values are shown as read from the document; the app never silently invents a value.

## Accessibility

- Text and controls meet WCAG AA contrast with the palette above (white on brand is about 5.4:1).
- Interactive targets are at least 44 pt tall.
- Selection is shown by more than colour (a check mark or label).
- Known gaps (tracked in the mobile PLAN): few explicit screen-reader labels, and large-text layouts have not been audited.
