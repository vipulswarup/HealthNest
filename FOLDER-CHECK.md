# Local folder check (Mac)

Decisions for importing a local health-file tree into SanoVault from the macOS Flutter app, then re-checking that folder on demand.

This file is the working spec. Update it whenever a decision changes.

Client: `sanovault-mobile` on macOS. Backend: existing `sanovault-web` APIs. SanoVault remains the source of truth after files are in the vault.

First target tree (example, not hardcoded):

```
~/vipulswarup@gmail.com - Google Drive/My Drive/Medical/Vipul
```

Other people under `Medical/` (Aaradhya, Mummy, and so on) are later runs: one patient at a time, same logic.

---

## Product shape

1. **One patient at a time.** A Folder Check is always scoped to one SanoVault person.
2. **Manual, not a watcher.** No auto-sync. The user invokes a folder check when they want one.
3. **Vault is canonical after ingest.** Nothing is written back to disk or Google Drive. Camera, share, and in-app uploads stay in SanoVault only.
4. **Remembered pairing.** First run: pick person + folder. Later runs reuse that pairing unless the user changes it.
5. **User-chosen exclusions.** For each pairing, the user can exclude specific subfolders. The exclusion list is remembered with the pairing. No patient-specific skip rules in code (for example do not hardcode `Vipul-PHR-Generator`).
6. **Mac UI.** Folder Check lives on the **More** tab (infrequent desktop action), not on Reports or the person profile.
7. **PDF passwords live on the person.** View/delete on the person profile on web, iOS, and Mac.

---

## What to ingest

Include, on **every** channel (Folder Check, web, iOS, Mac):

- PDFs
- Images (jpeg, png, and similar formats the vault already accepts)
- Microsoft Office files (Word, Excel, PowerPoint, and related Office types: `.doc`, `.docx`, `.xls`, `.xlsx`, `.ppt`, `.pptx`)

Skip on Folder Check:

- Google shortcuts (`.gdoc`, `.gsheet`, `.gform`, and similar)
- DICOM

Do not convert Office files to PDF for storage or for analysis.

Out of scope for this feature: a later local-only DICOM viewer/analyzer that does not store studies in the cloud vault.

---

## How files become records

- **One file, one health record.**
- Parent folder name becomes a tag.
- Parent folder name is also a hint for document date and doctor when the name looks like `Apr 2021 Covid` or `Dr. Das`.
- Loose files at the chosen folder root get no folder tag.
- Nested trees are walked in full, except excluded subfolders.

---

## Processing

- Upload first so the vault is usable immediately.
- PDFs and images: OCR and AI classification run later on a slow background queue (hours or days for a large tree).
- Office files: the server extracts native text (Word/Excel/PowerPoint parsers). No OCR and no PDF conversion. Classification uses that extracted text, same as OCR text for PDFs.
- Records stay on `needs_review` until the family confirms.

---

## Duplicates

Identity is content hash, compared against **every** document already stored for that patient: prior folder checks, camera, share sheet, and ordinary upload.

- Same bytes, any path or source: skip.
- Same relative path, new bytes: import as a new record. Leave the old vault record alone.
- Relative path is still recorded so the UI can show where a file came from, but hash is what prevents duplicates.

---

## Google Drive / online-only files

The source tree may live in Google Drive for Desktop. Online-only placeholders are not valid input.

- Before uploading, preflight every included file.
- If any included file is online-only (not fully on disk), **fail the whole scan**. Upload nothing from that run.
- Tell the user to make the tree available offline, then run Folder Check again.

---

## Password-protected PDFs

Lab PDFs are often encrypted. Unlocking is a **patient-level cloud capability**, not a Mac-only trick.

- Passwords are stored per SanoVault person in the cloud.
- The same password list and unlock loop apply to every ingest channel: Folder Check, web upload, camera, share sheet, and later channels.
- On a locked PDF: try saved passwords for that person. If none work, prompt. If the new password works, save it on that person and reuse it later.
- If a later file is not unlocked by any saved password, prompt again.
- Do not stop the whole scan on a locked PDF, and do not skip locked PDFs silently.
- The list is **household-shared** for that person: anyone who can upload for the person may use the passwords without the values being shown during upload.
- There is a settings screen on the **person profile** (Family tab on the apps, matching screen on the web) to view and delete saved passwords for that person. Same screen on web, iOS, and Mac.
- Folder Check does not manage the list; it only uses it and prompts when a new password is needed.
- Store the password values encrypted at rest. Do not log them.

The backend already has helpers for common date-of-birth password formats (`lib/pdf/passwords.ts`). Those can be tried in addition to saved passwords; they are not a substitute for the prompt-and-save loop.

---

## File size

- Same cap as web upload: **50 MB per file**.
- Files over the limit are skipped, listed in the scan summary, and the rest of the scan continues.
- This is not fail-fast (unlike online-only files).

---

## Pairing storage

- Person + folder + exclusion list is stored **on this Mac only** (security-scoped bookmark plus local app storage).
- A Mac can remember one folder per person (several people, several pairings). Folder Check still runs for one person at a time.
- A new Mac: pick the folder again and set exclusions again. Nothing about the pairing is in the cloud.

---

## Interrupted checks

- An interrupted check is **failed**. There is no resume state.
- The next Folder Check starts over from a full scan.
- Files that already reached the vault are still skipped by hash.

---

## Implementation plan

Product decisions above are closed. Build in this order so web/mobile gain Office + password + hash behavior before the Mac walk exists.

### Already in the codebase

- `documents.checksum_sha256` exists (`0001_initial.sql`) but is never written on upload (`document.service.ts` / `documents/upload`).
- Health-record create already supports `processAsync` and `scheduleHealthRecordProcessing` (`health-records/route.ts`, `document-ingest.service.ts`).
- Upload allow-list is PDF/images only (`file-signature.ts`, `DocumentUploader.tsx`).
- Mac sandbox already has `com.apple.security.files.user-selected.read-only`.
- `patients.preferences` JSONB exists; **do not** put PDF passwords there in plaintext. Use a dedicated encrypted table.
- DOB password format helpers already live in `lib/pdf/passwords.ts`.

### Phase 1 — Backend: hash, Office, passwords, shared unlock

Touched files (expected):

- `sanovault-web/database/migrations/0018_*.sql` — unique hash per patient (via `documents.patient_id` + `checksum_sha256`, or lookup join through `health_records`); `patient_file_passwords` (patient_id, encrypted_secret, created_by, created_at).
- `sanovault-web/lib/security/file-signature.ts` — accept Office: ZIP/PK for `.docx/.xlsx/.pptx`, OLE for `.doc/.xls/.ppt`.
- `sanovault-web/lib/services/document.service.ts` — write `checksum_sha256` on create; lookup by patient + hash.
- `sanovault-web/app/api/documents/upload/route.ts` — hash bytes; Office MIME; return existing document if this patient already has the hash (caller must pass patient id, or a dedicated `POST /api/documents/lookup-hash` used before upload).
- `sanovault-web/lib/services/office-text.service.ts` — **new**. Native text from Word/Excel/PowerPoint. No OCR, no PDF conversion.
- `sanovault-web/lib/services/document-ingest.service.ts` — PDF/image: OCR as today. Office: native text into `ocr_text`, then the same classify path.
- `sanovault-web/lib/services/pdf-unlock.service.ts` — **new**. Try saved passwords + DOB candidates; decrypt; persist a newly confirmed password.
- `sanovault-web/app/api/patients/[id]/file-passwords/route.ts` — **new**. List (values visible only on this settings API), add, delete. Household members who can access the person.
- `sanovault-web/app/api/patients/[id]/route.ts` — no password dump on the general patient GET.

Existing vault files have empty `checksum_sha256`. Without a backfill, Folder Check would re-import them. Phase 1 must either backfill hashes from R2 for that patient’s documents, or compute missing hashes lazily the first time a lookup runs.

### Phase 2 — Web and iOS: same file types and password UI

- `sanovault-web/components/documents/DocumentUploader.tsx` and add-report pages — allow Office extensions/MIME.
- `sanovault-web/app/patients/[id]/page.tsx` — “File passwords” manager.
- `sanovault-mobile/lib/features/reports/add_report_page.dart` — same allow-list.
- `sanovault-mobile/lib/features/family/person_detail_page.dart` — password manager.
- `sanovault-mobile/lib/api/sanovault_api.dart` — hash lookup, password CRUD, Office upload.

Upload, camera, and share all go through the same hash + unlock + extract pipeline.

### Phase 3 — macOS Folder Check

- `sanovault-mobile/lib/features/more/more_page.dart` — row that opens Folder Check (hidden or disabled on iOS).
- `sanovault-mobile/lib/features/folder_check/` — **new**: pairing editor, exclusion picker, preflight, progress, summary (uploaded / skipped duplicate / skipped oversized / failed).
- Local store: security-scoped bookmark + person id + excluded relative subfolder names. Not synced.
- Native Mac helper (Swift, via a small plugin or existing macos runner): persist bookmark, detect online-only Google Drive placeholders (fail the whole scan), SHA-256 files, read bytes.
- Flow: restore bookmark → walk tree → skip `.gdoc`/DICOM/excluded → if any included file is online-only, abort with zero uploads → skip >50 MB (list them) → hash → skip if vault has hash for that person → locked PDF: try cloud passwords, prompt, save on success → upload → `POST /api/health-records` with folder-name tag, date/doctor hints, `processAsync: true`, `needs_review`.
- Interrupted run: no resume file. Next invocation is a full walk; hashes skip completed uploads.

### Out of scope (later)

- Local DICOM viewer/analyzer (not stored in the vault).
- Writing files from SanoVault back to Drive.
- Folder Check on iOS.
- Auto-watching the folder.

---

## Open questions

None. Product decisions are closed.

---

## Decision log

| Date | Decision |
| --- | --- |
| 2026-09-16 | First import is one patient at a time. Starting example: `Medical/Vipul` only. |
| 2026-09-16 | No auto-sync. Manual folder check. Vault never writes back to disk. |
| 2026-09-16 | Ingest PDFs, images, Microsoft Office. Skip Google shortcuts and DICOM. Local DICOM viewing is later and not cloud-stored. |
| 2026-09-16 | One file = one record. Parent folder name is a tag and a date/doctor hint. |
| 2026-09-16 | Bulk: upload now, OCR/classify later on a slow queue, `needs_review`. |
| 2026-09-16 | Dedup by file hash against all vault files for that patient. Same path + new bytes = new record. |
| 2026-09-16 | Remember person + folder pairing. First run picks both. |
| 2026-09-16 | User can exclude subfolders per pairing; exclusions are remembered. Generic, not Vipul-specific. |
| 2026-09-16 | Fail the scan if any included file is online-only. |
| 2026-09-16 | Locked PDFs: prompt, reuse working passwords, prompt again on failure. |
| 2026-09-16 | Interrupted check is failed. Next run is a full scan; hash still skips completed uploads. |
| 2026-09-16 | PDF unlock passwords stored per person in the cloud. Same list and logic on every upload channel. |
| 2026-09-16 | Password list is household-shared for that person, with a settings screen to view and delete entries. Encrypted at rest. |
| 2026-09-16 | 50 MB per-file cap. Oversized files are skipped and listed; scan continues. |
| 2026-09-16 | Office files are first-class on web, mobile, and desktop. Store the original. Server extracts native text; no PDF conversion and no OCR for Office. |
| 2026-09-16 | Folder Check is a More-tab action on macOS. |
| 2026-09-16 | PDF password manager is on the person profile, on web, iOS, and Mac. Folder Check uses the list and prompts only when needed. |
| 2026-09-16 | Person+folder+exclusions stored on this Mac only. New Mac: pick the folder and exclusions again. One remembered folder per person per Mac. |
