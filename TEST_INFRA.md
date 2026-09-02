# Test Infrastructure & Methodology: LiquidCalc Serverless Backend Suite

## 1. Test Philosophy & Architecture

The LiquidCalc backend test infrastructure implements a **comprehensive opaque-box, requirement-driven verification architecture**. The test suite treats the serverless deployment as a black-box HTTP service, verifying external contracts, RFC specifications, Apple iOS deployment protocols, Google Generative Language streaming behaviors, and cross-feature workflows without relying on internal implementation details.

### 1.1 Core Methodologies
1. **Category-Partitioning**: Input and output domains across all 6 core functional domains are systematically partitioned into equivalence classes (e.g., valid payloads, missing keys, fallback headers, malformed types, boundary query params).
2. **Boundary Value Analysis (BVA)**: Exhaustive testing of parameter limits, empty collections, extreme mathematical expressions, pagination limits/offsets, semantic version boundaries (`2.3.0`, `1.0.0`, `3.0.0`), and XML entity escaping (`&`, `<`, `>`, `"`, `'`).
3. **Pairwise & Combinatorial Testing**: Verification of multi-endpoint workflows and state interactions (e.g., batch history sync -> AI equation solve -> history list verification; OTA manifest generation -> binary asset URL extraction -> IPA accessibility).
4. **Real-World Workload Testing**: High-fidelity emulation of client environments, including iOS 18 Mobile Safari, LiquidCalc Native Swift Client headers, base64 OCR image math inputs, unbuffered Server-Sent Events (SSE) streaming chunks, and Apple `itms-services` direct sideloading.

---

## 2. Feature Inventory & Multi-Tier Test Matrix

| # | Feature Domain | Source Endpoint | Tier 1 (Coverage) | Tier 2 (Boundaries) | Tier 3 (Cross-Feature) | Tier 4 (Real-World) |
|---|----------------|-----------------|:-----------------:|:-------------------:|:----------------------:|:-------------------:|
| **F1** | System Health & Diagnostics | `GET /api/health` | ✓ (Health status, uptime, services) | ✓ (Degraded handling, headers) | ✓ (Health during concurrency) | ✓ (Mobile client telemetry) |
| **F2** | Gemini 2.5 Flash SSE Stream | `POST /api/ai/stream` | ✓ (SSE stream chunks, done flag) | ✓ (Empty payload 400, API key fallback) | ✓ (Solve & stream pipelines) | ✓ (Unbuffered chunk latency) |
| **F3** | Structured Math/Receipt Solver | `POST /api/ai/solve` | ✓ (Math/receipt JSON schema) | ✓ (Extreme expressions, invalid mode) | ✓ (Solve -> Sync -> List flow) | ✓ (Base64 OCR image solve) |
| **F4** | Dynamic iOS OTA Manifest | `GET /api/ota/manifest` | ✓ (Apple XML plist DTD validation) | ✓ (Default params, XML sanitization) | ✓ (Manifest IPA link verify) | ✓ (1-tap `itms-services` link) |
| **F5** | iOS App IPA Binary Handler | `GET /api/ota/app` | ✓ (302 Redirect / stream) | ✓ (Version override query) | ✓ (Asset reachability check) | ✓ (iOS download headers) |
| **F6** | Version Update Checker | `GET /api/updates/check` | ✓ (Version 2.3.0 metadata) | ✓ (Equal, older, newer versions) | ✓ (OTA Manifest URL match) | ✓ (Native client check flow) |
| **F7** | Latest Release Metadata | `GET /api/updates/latest` | ✓ (GitHub/AltStore schema) | ✓ (Asset array validation) | ✓ (Release asset consistency) | ✓ (AltStore JSON feed) |
| **F8** | Calculation History Sync | `POST /api/history/sync` | ✓ (Batch item sync, count) | ✓ (Invalid schema, duplicate UUIDs) | ✓ (Batch sync -> List verify) | ✓ (Multi-mode batch sync) |
| **F9** | Calculation History Retrieval | `GET /api/history/list` | ✓ (Paginated items list) | ✓ (Mode filter, limit/offset edges) | ✓ (Persistence consistency) | ✓ (Client sync cycle) |
| **F10** | Status Dashboard & Explorer | `GET /` | ✓ (HTML glassmorphism render) | ✓ (Asset links, meta tags) | ✓ (Route link validity) | ✓ (iOS 18 Safari emulation) |
| **F11** | Universal CORS Preflight | `OPTIONS *` | ✓ (All API route OPTIONS) | ✓ (Custom headers, method list) | ✓ (Cross-origin AI/sync) | ✓ (Browser client headers) |
| **F12** | Concurrent Request Load | Multi-route | ✓ (Load resilience) | ✓ (Burst capacity) | ✓ (20+ concurrent requests) | ✓ (Sustained throughput) |

---

## 3. Test Suite Architecture

The test harness is implemented in modern, zero-dependency Node.js ESM (`.mjs`), utilizing native `fetch`, `AbortController`, `crypto`, and streaming `ReadableStream` readers.

```
backend/
├── verify_live_backend.mjs        # Master E2E CLI Runner (CLI flags, reporting, exit codes)
└── tests/
    ├── test_utils.mjs             # Assertion library, color formatting, timing, XML validators
    ├── tier1_features.mjs         # Tier 1: Baseline Feature Coverage (10+ tests)
    ├── tier2_boundaries.mjs       # Tier 2: Boundary & Corner Cases (10+ tests)
    ├── tier3_cross_feature.mjs    # Tier 3: Cross-Feature Integration & Stress (5+ tests)
    └── tier4_real_world.mjs       # Tier 4: Real-World Scenarios & Emulation (5+ tests)
```

### 3.1 Runner Capabilities
- **Target Agnostic**: Supports local dev servers (`http://localhost:3000`) and live HTTPS production Vercel deployments (`https://*.vercel.app`) via `--url <TARGET_URL>`.
- **Selective Execution**: Target specific tiers with `--tier 1`, `--tier 2`, `--tier 3`, `--tier 4`, or `--tier all`.
- **API Key Ingestion**: Accepts test keys via `--key <GEMINI_API_KEY>` or environment variables (`GEMINI_API_KEY`).
- **Telemetry & Diagnostics**: Detailed per-test latency timing (ms), payload summaries, and failure traces.
- **Strict Exit Codes**: Returns `0` on 100% suite pass; returns `1` on any assertion or network failure for CI/CD gating.

---

## 4. Test Tier Specifications

### Tier 1: Baseline Feature Coverage
Verifies that all 10 core backend endpoints fulfill their primary functional contracts:
1. `GET /api/health` -> HTTP 200, `status: "operational"`, `healthy: true`, `version: "2.3.0"`, `services` dictionary.
2. `POST /api/ai/stream` -> HTTP 200, `Content-Type: text/event-stream`, SSE chunks containing `data: {"text": "..."}` and completion signal `data: {"text": "", "done": true}`.
3. `POST /api/ai/solve` -> HTTP 200, `application/json`, valid structured response `{ success: true, expression, result, steps, explanation }`.
4. `GET /api/ota/manifest` -> HTTP 200, `Content-Type: text/xml`, valid Apple DTD `software-package` plist with `bundle-identifier`, `bundle-version`, `kind=software`, `title`.
5. `GET /api/ota/app` -> HTTP 302 Redirect / 200 Stream pointing to `LiquidCalc.ipa`.
6. `GET /api/updates/check` -> HTTP 200, `latestVersion: "2.3.0"`, `buildNumber: "23"`, `otaManifestURL`, `otaInstallURL`, `changelog`.
7. `GET /api/updates/latest` -> HTTP 200, `tag_name: "v2.3.0"`, `assets` array containing IPA binary download metadata.
8. `POST /api/history/sync` -> HTTP 200, batch sync response `{ success: true, syncedCount, totalRecords }`.
9. `GET /api/history/list` -> HTTP 200, paginated history retrieval `{ success: true, count, total, items }`.
10. `GET /` -> HTTP 200, `Content-Type: text/html`, dark glassmorphism dashboard markup with service status indicators.

### Tier 2: Boundary & Corner Cases
Tests system behavior at boundary conditions, malformed payloads, and edge parameters:
1. **Default Query Params on OTA Manifest**: Requesting bare `GET /api/ota/manifest` without params defaults cleanly to `com.liquidcalc.app`, `LiquidCalc`, `2.3.0`.
2. **Special Characters & XML Escaping**: `GET /api/ota/manifest?name=Liquid%20%26%20Calc%20%3CBeta%3E&version=2.3.0-rc1` generates valid, escaped XML without malforming the plist.
3. **Empty Body Handling**: `POST /api/ai/stream` with `{}` returns HTTP 400 Bad Request `{ error: "Prompt or image is required" }`.
4. **Invalid Solver Payload**: `POST /api/ai/solve` with missing expression and image returns HTTP 400 Bad Request.
5. **Malformed History Sync Payload**: `POST /api/history/sync` with non-array items or invalid schema returns HTTP 400 Bad Request.
6. **Universal CORS Preflight across All Endpoints**: `OPTIONS` requests to `/api/health`, `/api/ai/stream`, `/api/ai/solve`, `/api/ota/manifest`, `/api/updates/check`, `/api/history/sync`, `/api/history/list` return HTTP 200/204 with valid `Access-Control-Allow-Origin: *`, `Access-Control-Allow-Methods`, and `Access-Control-Allow-Headers`.
7. **Gemini API Key Header Fallback**: In the absence of server environment key, `POST /api/ai/stream` correctly respects `x-gemini-api-key` and `Authorization: Bearer <KEY>` headers.
8. **History Pagination Boundaries**: `GET /api/history/list` with `limit=0`, `limit=1`, `limit=200`, `offset=0`, and out-of-bounds `offset=1000` returns valid responses without crash.
9. **Semantic Version Comparison Boundaries**:
   - Older version (`currentVersion=2.2.0`) -> `updateAvailable: true`.
   - Current version (`currentVersion=2.3.0`) -> `updateAvailable: false`.
   - Future version (`currentVersion=3.0.0`) -> `updateAvailable: false`.
10. **Extreme Math Expression Parsing**: `POST /api/ai/solve` handles complex multi-operator LaTeX equations and nested parentheses without crashing.

### Tier 3: Cross-Feature Combinations
Validates interdependent workflows and multi-service state consistency:
1. **Sync -> AI Solve -> List Integration Workflow**:
   - Post initial math record via `POST /api/history/sync`.
   - Execute an AI math solve via `POST /api/ai/solve`.
   - Store the solved result via `POST /api/history/sync`.
   - Retrieve full list via `GET /api/history/list` and assert both records are present with correct timestamps and modes.
2. **OTA Manifest to IPA Asset Accessibility**:
   - Request `GET /api/ota/manifest`.
   - Extract the `.ipa` URL from `<key>url</key><string>...</string>`.
   - Assert `GET /api/ota/app` redirects directly to the same `.ipa` binary URL.
3. **Update Check to OTA Manifest Consistency**:
   - Query `GET /api/updates/check`.
   - Fetch the embedded `otaManifestURL` and verify it returns a valid Apple XML plist matching `latestVersion`.
   - Verify `otaInstallURL` is properly formatted with `itms-services://?action=download-manifest&url=...`.
4. **Concurrent Burst Stress Testing**:
   - Dispatch 20 concurrent asynchronous requests spanning `/api/health`, `/api/history/list`, `/api/updates/check`, and `/api/ota/manifest`.
   - Assert 100% HTTP 200 response rate with zero 5xx serverless crashes and sub-500ms average latency.

### Tier 4: Real-World Scenarios & Workload Emulation
Emulates exact real-world production client interactions:
1. **iOS 18 Mobile Safari Client Emulation**:
   - Header: `User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1`
   - Request `/` and `/api/ota/manifest` verifying mobile-friendly viewport meta tags, glassmorphism CSS, and plist delivery.
2. **LiquidCalc Native iOS App User-Agent**:
   - Header: `User-Agent: LiquidCalc/2.3.0 (iPhone; iOS 18.0; Scale/3.00)`
   - Complete standard app launch cycle: check updates -> sync calculation history -> list history.
3. **Base64 Multimodal OCR Math Solving**:
   - Send valid Base64 image data URI (`data:image/png;base64,...`) to `POST /api/ai/solve`.
   - Verify serverless gateway decodes image data and produces structured math breakdown.
4. **1-Tap iOS OTA Direct Installation Verification**:
   - Emulate iOS Safari opening `itms-services://?action=download-manifest&url=https%3A%2F%2F...%2Fapi%2Fota%2Fmanifest`.
   - Extract manifest target URL, download XML, and verify compliance with Apple Enterprise/Ad-Hoc App Distribution specification.
5. **SSE Unbuffered Streaming Latency & Chunk Delivery**:
   - Connect to `POST /api/ai/stream` with streaming reader.
   - Verify `Cache-Control: no-cache` and `X-Accel-Buffering: no` preventing serverless proxy buffering.
   - Capture individual text chunks incrementally before stream close.

---

## 5. Coverage Thresholds & Quality Gates

| Metric | Minimum Threshold | Target |
|--------|:-----------------:|:------:|
| **Tier 1 (Feature Coverage)** | ≥ 10 Tests | 100% Pass |
| **Tier 2 (Boundaries & Edge Cases)** | ≥ 10 Tests | 100% Pass |
| **Tier 3 (Cross-Feature Combinations)** | ≥ 4 Tests | 100% Pass |
| **Tier 4 (Real-World Scenarios)** | ≥ 5 Tests | 100% Pass |
| **Total Test Count** | ≥ 29 Tests | 100% Pass |
| **HTTP Success Rate** | 100% (No unhandled 500s) | 100% |
| **CORS Coverage** | 100% of API endpoints | 100% |
| **XML Plist DTD Compliance** | 100% Apple RFC Compliant | 100% |

---

## 6. Execution Command

```bash
# Run against local development server
node backend/verify_live_backend.mjs --url http://localhost:3000

# Run against live Vercel production deployment
node backend/verify_live_backend.mjs --url https://liquidcalc.vercel.app

# Run specific tier with verbose logs
node backend/verify_live_backend.mjs --url http://localhost:3000 --tier 1 --verbose
```
