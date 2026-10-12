# SanoVault

SanoVault is a privacy-first personal health record for families. It keeps medical documents, family profiles, symptom notes, blood pressure and medicines in one place, reads documents with OCR and AI (only with consent), and prepares a short, doctor-ready packet.

## What is in this repository

| Folder | What it is | Start here |
| --- | --- | --- |
| [`sanovault-web`](./sanovault-web) | The website **and** the API used by the app: Next.js, Neon Postgres, Cloudflare R2, Groq | [README](./sanovault-web/README.md) |
| [`sanovault-mobile`](./sanovault-mobile) | Flutter app for iOS, Android and macOS (Cupertino design) | [README](./sanovault-mobile/README.md) |
| [`icons`](./icons) | App icons and store artwork for every platform | [icons/README.txt](./icons/README.txt) |
| [`test-data`](./test-data) | Sample documents for manual testing | |

## Documents

Each document has one job.

| Document | Covers |
| --- | --- |
| [DESIGN.md](./DESIGN.md) | Shared palette, navigation, ordering rules, offline and speed principles |
| [FOLDER-CHECK.md](./FOLDER-CHECK.md) | Product spec for importing a local folder on a Mac |
| [sanovault-web/README.md](./sanovault-web/README.md) | Web setup, environment variables, scripts, API reference, database |
| [sanovault-web/DEPLOYMENT.md](./sanovault-web/DEPLOYMENT.md) | Production hosting, regions, cron jobs, WhatsApp, account deletion |
| [sanovault-web/TROUBLESHOOTING.md](./sanovault-web/TROUBLESHOOTING.md) | Build, environment, migration and runtime problems |
| [sanovault-web/docs/](./sanovault-web/docs) | Medication Center spec; August 2026 usability review |
| [sanovault-mobile/README.md](./sanovault-mobile/README.md) | Run, test and release the app |
| [sanovault-mobile/PLAN.md](./sanovault-mobile/PLAN.md) | Mobile scope, architecture, status and open work |

## Quick start

```bash
# API and website
cd sanovault-web && npm install && cp .env.example .env.local   # fill in values
npm run db:migrate && npm run dev                                # http://localhost:3001

# Mobile app against the local API
cd sanovault-mobile && flutter pub get
flutter run --dart-define=API_URL=http://localhost:3001
```

## Branching and deployment

`main` deploys to production on Vercel (project root `sanovault-web`). Work on a branch; every branch gets a preview deployment. Deploy API changes before releasing an app build that uses them. Details: [DEPLOYMENT.md](./sanovault-web/DEPLOYMENT.md).

## License

MIT. See [LICENSE](./LICENSE).
