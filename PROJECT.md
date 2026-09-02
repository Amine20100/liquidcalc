# Project: LiquidCalc Next.js Serverless Backend Suite

## Architecture
- **Framework**: Next.js 14/15 App Router (`TypeScript`, `Tailwind CSS`, `Lucide React`)
- **Execution Target**: Vercel Serverless / Edge Functions (`iad1`)
- **Live Production URL**: `https://liquidcalc-backend.vercel.app`
- **Styling**: Cyberpunk dark glassmorphism theme (`#07090e`, neon cyan `#00F0FF`, purple `#7928CA`, emerald `#00FFA3`)
- **Key Modules**:
  - `app/api/health`: System health & liveness probe
  - `app/api/ai/stream`: Gemini 2.5 Flash Server-Sent Events (SSE) streaming proxy
  - `app/api/ai/solve`: Structured JSON math & receipt solver with OCR support
  - `app/api/ota/manifest`: Dynamic Apple `itms-services` software-package XML plist generator
  - `app/api/ota/app`: IPA binary download & redirect handler
  - `app/api/updates/check`: App version 2.3.0 & update check distribution
  - `app/api/updates/latest`: GitHub & AltStore compatible release metadata
  - `app/api/history/sync`: Calculation history & math notes batch synchronization
  - `app/api/history/list`: Paginated calculation history retrieval
  - `app/page.tsx`: Cyberpunk Dark Status Dashboard, live service telemetry & interactive API explorer
  - `lib/gemini.ts`: Google Generative Language API client with env & header authentication
  - `lib/ota.ts`: Apple XML property list generator
  - `lib/storage.ts`: In-memory calculation history sync engine
  - `lib/cors.ts`: Universal permissive CORS & preflight options handler

## Code Layout
```
backend/
├── app/
│   ├── api/
│   │   ├── health/
│   │   │   └── route.ts
│   │   ├── ai/
│   │   │   ├── stream/
│   │   │   │   └── route.ts
│   │   │   └── solve/
│   │   │       └── route.ts
│   │   ├── ota/
│   │   │   ├── manifest/
│   │   │   │   └── route.ts
│   │   │   └── app/
│   │   │       └── route.ts
│   │   ├── updates/
│   │   │   ├── check/
│   │   │   │   └── route.ts
│   │   │   └── latest/
│   │   │       └── route.ts
│   │   └── history/
│   │       ├── sync/
│   │       │   └── route.ts
│   │       └── list/
│   │           └── route.ts
│   ├── globals.css
│   ├── layout.tsx
│   └── page.tsx
├── lib/
│   ├── gemini.ts
│   ├── ota.ts
│   ├── storage.ts
│   └── cors.ts
├── public/
│   └── favicon.ico
├── tests/
│   ├── e2e_runner.mjs
│   ├── test_utils.mjs
│   ├── tier1_features.mjs
│   ├── tier2_boundaries.mjs
│   ├── tier3_cross_feature.mjs
│   ├── tier4_real_world.mjs
│   └── tier5_live_adversarial.mjs
├── vercel.json
├── package.json
├── tsconfig.json
├── tailwind.config.ts
├── postcss.config.mjs
├── next.config.mjs
└── verify_live_backend.mjs
```

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Health Check (`/api/health`) | System health, uptime, timestamp, subservice status | M1 | ORIGINAL_REQUEST §R1 |
| 2 | Gemini AI Stream Proxy (`/api/ai/stream`) | Real-time SSE streaming for Gemini 2.5 Flash, multi-turn memory, multimodal OCR | M2 | ORIGINAL_REQUEST §R1 |
| 3 | Gemini AI Structured Solver (`/api/ai/solve`) | Structured math equation solving and receipt OCR parsing | M2 | ORIGINAL_REQUEST §R1 |
| 4 | Gemini Key Header Fallback | Environment key with `x-gemini-api-key` & `Authorization` fallback | M2 | ORIGINAL_REQUEST §R1 |
| 5 | Dynamic iOS OTA Manifest (`/api/ota/manifest`) | Apple `itms-services` software-package XML plist generator | M3 | ORIGINAL_REQUEST §R1 |
| 6 | iOS App Download Handler (`/api/ota/app`) | IPA binary download & redirect handler | M3 | ORIGINAL_REQUEST §R1 |
| 7 | Version Update Checker (`/api/updates/check`) | Version 2.3.0 release metadata, build number, changelog | M4 | ORIGINAL_REQUEST §R1 |
| 8 | Latest Release Metadata (`/api/updates/latest`) | GitHub & AltStore release payload with asset URLs | M4 | ORIGINAL_REQUEST §R1 |
| 9 | History Sync (`/api/history/sync`) | Batch sync and backup of calculation records & notes | M5 | ORIGINAL_REQUEST §R1 |
| 10 | History Retrieval (`/api/history/list`) | Paginated retrieval and mode filtering for calculation history | M5 | ORIGINAL_REQUEST §R1 |
| 11 | Dark Cyberpunk Dashboard (`/`) | Modern glassmorphism status dashboard with telemetry & API explorer | M6 | ORIGINAL_REQUEST §R1 |
| 12 | Vercel Serverless Config | `vercel.json` and Next.js serverless route configuration | M7 | ORIGINAL_REQUEST §R2 |
| 13 | Vercel CLI Production Deploy | Production deployment using Vercel token via CLI | M7 | ORIGINAL_REQUEST §R2 |
| 14 | 4-Tier Automated E2E Test Suite | Comprehensive opaque-box test runner validating all endpoints | M8 | ORIGINAL_REQUEST §R3 |
| 15 | Live Production Verification | Automated verification against live `https://liquidcalc-backend.vercel.app` URL with 100% pass | M9 | ORIGINAL_REQUEST §Acceptance |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Project Scaffolding & Health API | Next.js setup, TypeScript, Tailwind, Lucide, `/api/health`, CORS lib | none | DONE |
| M2 | Gemini 2.5 Flash Gateway & Solver | `/api/ai/stream` (SSE), `/api/ai/solve`, multimodal OCR, auth fallback | M1 | DONE |
| M3 | iOS OTA Manifest & Sideloading Hub | `/api/ota/manifest` (Apple plist XML), `/api/ota/app` | M1 | DONE |
| M4 | App Update & Distribution Engine | `/api/updates/check`, `/api/updates/latest` (v2.3.0, changelog) | M1 | DONE |
| M5 | History Sync & Retrieval Engine | `/api/history/sync`, `/api/history/list`, `lib/storage.ts` | M1 | DONE |
| M6 | Cyberpunk Dark Status Dashboard | Root page `/` UI, glassmorphism CSS, live telemetry & interactive sandbox | M1-M5 | DONE |
| M7 | E2E Testing Suite (Tiers 1-4) | Requirements-driven test runner, `TEST_INFRA.md`, `TEST_READY.md` | none | DONE |
| M8 | Local Verification & Quality Gate | Local build, test execution, Reviewer, Challenger & Forensic Audit gate | M1-M7 | DONE |
| M9 | Vercel Production Deployment | CLI deployment with token, link, production release URL generation | M8 | DONE |
| M10 | Live Verification & Tier 5 Hardening | Automated live E2E test run on Vercel URL, Tier 5 adversarial hardening | M9 | DONE |

## Interface Contracts
### AI Gateway (`/api/ai/stream`, `/api/ai/solve`)
- `POST /api/ai/stream`: Body `{ prompt: string, history?: Array<{role: string, text: string}>, image?: string, temperature?: number }` -> `text/event-stream` chunks `data: {"text": string, "done": boolean}\n\n`
- `POST /api/ai/solve`: Body `{ mode: "math" | "receipt", expression?: string, image?: string }` -> `application/json` `{ success: boolean, expression: string, result: string, steps: string[], explanation: string }`
- Fallback Auth: `process.env.GEMINI_API_KEY` -> `req.headers['x-gemini-api-key']` -> `req.headers['authorization']`

### Dynamic iOS OTA (`/api/ota/manifest`, `/api/ota/app`)
- `GET /api/ota/manifest?bundleId=...&name=...&version=...`: Query params optional with defaults -> `text/xml; charset=utf-8` conforming to Apple DTD `software-package` plist.
- `GET /api/ota/app`: -> `302 Redirect` to latest GitHub release IPA.

### Updates Distribution (`/api/updates/check`, `/api/updates/latest`)
- `GET /api/updates/check?currentVersion=...`: -> `{ updateAvailable: boolean, currentVersion: string, latestVersion: "2.3.0", buildNumber: "23", downloadURL: string, otaManifestURL: string, otaInstallURL: string, changelog: string[] }`
- `GET /api/updates/latest`: -> GitHub release & AltStore asset object.

### History Sync (`/api/history/sync`, `/api/history/list`)
- `POST /api/history/sync`: Body `{ deviceId?: string, items: Array<{ id: string, timestamp: string, expression: string, result: string, mode: string, notes?: string }> }` -> `{ success: true, syncedCount: number, totalRecords: number, lastSyncTimestamp: string }`
- `GET /api/history/list?mode=...&limit=...&offset=...`: -> `{ success: true, count: number, total: number, items: Array<HistoryItem> }`

### System Health (`/api/health`)
- `GET /api/health`: -> `{ status: "operational", healthy: true, timestamp: string, uptime: number, version: "2.3.0", services: { gemini_gateway: {...}, ota_signer: {...}, updates_dist: {...}, history_sync: {...} } }`
