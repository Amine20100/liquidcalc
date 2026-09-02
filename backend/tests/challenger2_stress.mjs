/**
 * Empirical Challenger 2 Stress Test Harness
 * 
 * Deeply challenges:
 * 1. Multimodal OCR payloads (valid, malformed, large, corrupted, unexpected mime types, raw base64, concurrent OCR)
 * 2. Large batch history syncs (100+ records, duplicate IDs, duplicate timestamps, out-of-order timestamps, edge fields)
 * 3. Pagination boundary conditions (limit 0, negative, extreme, NaN, offset boundary conditions, filtering interactions)
 * 4. Universal CORS preflight & headers across ALL routes with various Origin & Request-Headers
 */

import { fetchWithTimeout, assert, assertEqual, assertStatus } from './test_utils.mjs';

const BASE_URL = process.env.TEST_URL || 'http://localhost:3000';
const TIMEOUT = 15000;

const results = {
  passed: 0,
  failed: 0,
  tests: [],
};

async function test(name, fn) {
  const start = performance.now();
  try {
    await fn();
    const duration = Math.round(performance.now() - start);
    results.passed++;
    results.tests.push({ name, status: 'PASS', duration });
    console.log(`  ✓ PASS [${duration}ms] ${name}`);
  } catch (err) {
    const duration = Math.round(performance.now() - start);
    results.failed++;
    results.tests.push({ name, status: 'FAIL', duration, error: err.message });
    console.log(`  ✗ FAIL [${duration}ms] ${name}\n     Error: ${err.message}`);
  }
}

// 1x1 transparent PNG base64
const VALID_1X1_PNG_BASE64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==";
const VALID_PNG_DATA_URL = `data:image/png;base64,${VALID_1X1_PNG_BASE64}`;
const VALID_JPEG_DATA_URL = `data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=`;

async function runMultimodalOcrChallenges() {
  console.log('\n=== SECTION 1: MULTIMODAL OCR PAYLOAD CHALLENGES ===');

  await test('OCR 1.1: Math solver with standard PNG data URL', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/ai/solve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        mode: 'math',
        image: VALID_PNG_DATA_URL,
        prompt: 'Solve equation in image',
      }),
    }, TIMEOUT);
    assertStatus(res, 200);
    const data = await res.json();
    assert(data.success === true, 'Response must indicate success');
    assert(typeof data.result === 'string', 'Result must be a string');
    assert(Array.isArray(data.steps), 'Steps must be an array');
  });

  await test('OCR 1.2: Receipt solver with JPEG data URL', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/ai/solve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        mode: 'receipt',
        image: VALID_JPEG_DATA_URL,
      }),
    }, TIMEOUT);
    assertStatus(res, 200);
    const data = await res.json();
    assert(data.success === true, 'Receipt response must indicate success');
    assert(data.mode === 'receipt', 'Mode must be receipt');
    assert(typeof data.total === 'number', 'Total must be numeric');
    assert(Array.isArray(data.items), 'Items must be an array');
  });

  await test('OCR 1.3: Raw base64 string without data: URL prefix', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/ai/solve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        mode: 'math',
        image: VALID_1X1_PNG_BASE64,
        expression: '3*x + 9 = 0',
      }),
    }, TIMEOUT);
    assertStatus(res, 200);
    const data = await res.json();
    assert(data.success === true, 'Must handle raw base64 string gracefully');
  });

  await test('OCR 1.4: Corrupted / invalid base64 string handling', async () => {
    const corruptedBase64 = "data:image/png;base64,!!!NOT_VALID_BASE64_GARBAGE$$$%%%";
    const res = await fetchWithTimeout(`${BASE_URL}/api/ai/solve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        mode: 'math',
        image: corruptedBase64,
        expression: '4 + 4',
      }),
    }, TIMEOUT);
    // Should gracefully process or fallback without unhandled 500 crash
    assert([200, 400, 422].includes(res.status), `Expected 200 or 400/422, got ${res.status}`);
    const data = await res.json();
    if (res.status === 200) {
      assert(data.success === true, 'Fallback should provide valid math solution');
    }
  });

  await test('OCR 1.5: Unusual MIME type (data:image/webp;base64)', async () => {
    const webpDataUrl = "data:image/webp;base64,UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA==";
    const res = await fetchWithTimeout(`${BASE_URL}/api/ai/solve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        mode: 'math',
        image: webpDataUrl,
      }),
    }, TIMEOUT);
    assertStatus(res, 200);
    const data = await res.json();
    assert(data.success === true, 'WebP image must be accepted');
  });

  await test('OCR 1.6: Large image payload stress (~500KB base64)', async () => {
    const largePadding = "A".repeat(500000);
    const largeImage = `data:image/png;base64,${VALID_1X1_PNG_BASE64}${largePadding}`;
    const res = await fetchWithTimeout(`${BASE_URL}/api/ai/solve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        mode: 'math',
        image: largeImage,
        expression: '100 / 4',
      }),
    }, 20000);
    assert([200, 400, 413, 422].includes(res.status), `Server should handle large payload cleanly (status: ${res.status})`);
  });

  await test('OCR 1.7: SSE Stream with multimodal image input (POST /api/ai/stream)', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/ai/stream`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        prompt: 'Analyze equation in image',
        image: VALID_PNG_DATA_URL,
      }),
    }, TIMEOUT);
    assertStatus(res, 200);
    const contentType = res.headers.get('content-type') || '';
    assert(contentType.includes('text/event-stream'), `Content-Type must be text/event-stream (got ${contentType})`);
    
    const bodyText = await res.text();
    assert(bodyText.includes('data:'), 'SSE stream must emit data chunks');
    assert(bodyText.includes('"done":true') || bodyText.includes('"done": true'), 'SSE stream must terminate with done: true');
  });

  await test('OCR 1.8: Concurrent OCR solve requests (5 parallel requests)', async () => {
    const requests = Array.from({ length: 5 }).map((_, i) =>
      fetchWithTimeout(`${BASE_URL}/api/ai/solve`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          mode: i % 2 === 0 ? 'math' : 'receipt',
          image: i % 2 === 0 ? VALID_PNG_DATA_URL : VALID_JPEG_DATA_URL,
          expression: `10 * ${i + 1}`,
        }),
      }, TIMEOUT)
    );
    const responses = await Promise.all(requests);
    for (const res of responses) {
      assertStatus(res, 200);
      const data = await res.json();
      assert(data.success === true, 'Concurrent OCR response must be successful');
    }
  });
}

async function runBatchHistorySyncChallenges() {
  console.log('\n=== SECTION 2: LARGE BATCH HISTORY SYNC CHALLENGES ===');

  await test('Sync 2.1: Large batch synchronization (120 records)', async () => {
    const batchSize = 120;
    const items = [];
    const baseTime = Date.now() - 1000000;

    for (let i = 0; i < batchSize; i++) {
      items.push({
        id: `batch_item_${i}_${Date.now()}`,
        timestamp: new Date(baseTime + i * 1000).toISOString(),
        expression: `x^${i} + ${i} = 0`,
        result: `x = -${i}`,
        mode: i % 3 === 0 ? 'calculus' : i % 3 === 1 ? 'matrix' : 'standard',
        notes: `Auto-generated batch stress test note #${i}`,
        deviceId: 'device_stress_100',
      });
    }

    const res = await fetchWithTimeout(`${BASE_URL}/api/history/sync`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        deviceId: 'device_stress_100',
        items,
      }),
    }, TIMEOUT);
    assertStatus(res, 200);
    const data = await res.json();
    assert(data.success === true, 'Batch sync must succeed');
    assert(data.syncedCount === batchSize, `syncedCount should be ${batchSize}, got ${data.syncedCount}`);
    assert(data.totalRecords >= batchSize, `totalRecords should be at least ${batchSize}`);
  });

  await test('Sync 2.2: Duplicate IDs within the same batch (Deduplication / Update)', async () => {
    const sharedId = `dup_id_${Date.now()}`;
    const items = [
      {
        id: sharedId,
        timestamp: '2026-09-02T01:00:00.000Z',
        expression: '1 + 1',
        result: '2',
        mode: 'standard',
      },
      {
        id: sharedId, // Same ID, updated value
        timestamp: '2026-09-02T02:00:00.000Z',
        expression: '1 + 1 (updated)',
        result: '2 (updated)',
        mode: 'standard',
      },
    ];

    const res = await fetchWithTimeout(`${BASE_URL}/api/history/sync`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ items }),
    }, TIMEOUT);
    assertStatus(res, 200);
    const data = await res.json();
    assert(data.success === true, 'Batch sync with duplicate IDs must succeed');
    assert(data.syncedCount === 2, 'Should process both entries');

    // Verify list returns only the latest updated version of the item
    const listRes = await fetchWithTimeout(`${BASE_URL}/api/history/list?search=updated`, { method: 'GET' }, TIMEOUT);
    assertStatus(listRes, 200);
    const listData = await listRes.json();
    const matched = listData.items.filter(it => it.id === sharedId);
    assertEqual(matched.length, 1, 'Duplicate ID must be deduplicated in store');
    assertEqual(matched[0].expression, '1 + 1 (updated)', 'Latest update must overwrite previous item');
  });

  await test('Sync 2.3: Duplicate and out-of-order timestamps chronological sorting test', async () => {
    const testDeviceId = `sort_test_dev_${Date.now()}`;
    const timestampFixed = '2026-08-15T12:00:00.000Z';
    
    // Insert out of order: 2020, 2026, 1999, 2025, duplicate 2026
    const items = [
      { id: `t_2020_${Date.now()}`, timestamp: '2020-01-01T00:00:00.000Z', expression: 'yr_2020', result: '2020', mode: 'standard', deviceId: testDeviceId },
      { id: `t_2026_a_${Date.now()}`, timestamp: timestampFixed, expression: 'yr_2026_a', result: '2026', mode: 'standard', deviceId: testDeviceId },
      { id: `t_1999_${Date.now()}`, timestamp: '1999-12-31T23:59:59.000Z', expression: 'yr_1999', result: '1999', mode: 'standard', deviceId: testDeviceId },
      { id: `t_2025_${Date.now()}`, timestamp: '2025-06-01T00:00:00.000Z', expression: 'yr_2025', result: '2025', mode: 'standard', deviceId: testDeviceId },
      { id: `t_2026_b_${Date.now()}`, timestamp: timestampFixed, expression: 'yr_2026_b', result: '2026', mode: 'standard', deviceId: testDeviceId },
    ];

    const res = await fetchWithTimeout(`${BASE_URL}/api/history/sync`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ items }),
    }, TIMEOUT);
    assertStatus(res, 200);

    // Retrieve sorted list for this device
    const listRes = await fetchWithTimeout(`${BASE_URL}/api/history/list?deviceId=${testDeviceId}&limit=10`, { method: 'GET' }, TIMEOUT);
    assertStatus(listRes, 200);
    const listData = await listRes.json();
    assertEqual(listData.items.length, 5, 'Should retrieve all 5 records');

    // Verify chronological descending order (newest first)
    for (let i = 0; i < listData.items.length - 1; i++) {
      const curTime = new Date(listData.items[i].timestamp).getTime();
      const nextTime = new Date(listData.items[i + 1].timestamp).getTime();
      assert(curTime >= nextTime, `Records must be sorted newest first (${listData.items[i].expression} vs ${listData.items[i+1].expression})`);
    }
  });

  await test('Sync 2.4: Empty batch and partial / invalid record handling', async () => {
    // Empty array sync
    const resEmpty = await fetchWithTimeout(`${BASE_URL}/api/history/sync`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ items: [] }),
    }, TIMEOUT);
    assertStatus(resEmpty, 200);
    const dataEmpty = await resEmpty.json();
    assertEqual(dataEmpty.syncedCount, 0, 'Empty batch should sync 0 records');

    // Partial items: item with missing expression and result should be skipped
    const partialItems = [
      { id: 'valid_1', expression: '10+10', result: '20' },
      { id: 'invalid_empty', expression: '', result: '' }, // Should be skipped
      null, // null entry in array
      { id: 'valid_2', expression: '20+20', result: '40' },
    ];
    const resPartial = await fetchWithTimeout(`${BASE_URL}/api/history/sync`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ items: partialItems }),
    }, TIMEOUT);
    assertStatus(resPartial, 200);
    const dataPartial = await resPartial.json();
    assertEqual(dataPartial.syncedCount, 2, 'Only valid non-empty items should be synced');
  });

  await test('Sync 2.5: Extreme expression contents (Unicode, LaTeX, Math symbols, Special Characters)', async () => {
    const complexExpr = "∫_{0}^{∞} e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2} ⚡ 🚀 ∑_{n=1}^∞ 1/n^2 = π^2/6 <script>alert('xss')</script>";
    const items = [
      {
        id: `unicode_test_${Date.now()}`,
        timestamp: new Date().toISOString(),
        expression: complexExpr,
        result: "√π / 2 & π²/6",
        mode: "calculus",
        notes: "Extreme unicode math symbols and potential xss tag",
      }
    ];

    const res = await fetchWithTimeout(`${BASE_URL}/api/history/sync`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ items }),
    }, TIMEOUT);
    assertStatus(res, 200);

    const listRes = await fetchWithTimeout(`${BASE_URL}/api/history/list?search=xss`, { method: 'GET' }, TIMEOUT);
    assertStatus(listRes, 200);
    const listData = await listRes.json();
    assert(listData.items.length >= 1, 'Must preserve and search unicode characters accurately');
    assertEqual(listData.items[0].expression, complexExpr, 'Expression string must match verbatim');
  });
}

async function runPaginationBoundaryChallenges() {
  console.log('\n=== SECTION 3: PAGINATION BOUNDARY CONDITIONS ===');

  await test('PAG 3.1: limit=0 boundary handling', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/history/list?limit=0`, { method: 'GET' }, TIMEOUT);
    assertStatus(res, 200);
    const data = await res.json();
    assert(data.items.length >= 1, 'limit=0 must clamp to minimum allowed limit (>= 1)');
  });

  await test('PAG 3.2: Negative limit and negative offset (limit=-5, offset=-10)', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/history/list?limit=-5&offset=-10`, { method: 'GET' }, TIMEOUT);
    assertStatus(res, 200);
    const data = await res.json();
    assertEqual(data.offset, 0, 'Negative offset must clamp to 0');
    assert(data.limit >= 1, 'Negative limit must clamp to >= 1');
    assert(Array.isArray(data.items), 'Must return items array');
  });

  await test('PAG 3.3: Upper bound limit clamping (limit=5000)', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/history/list?limit=5000`, { method: 'GET' }, TIMEOUT);
    assertStatus(res, 200);
    const data = await res.json();
    assert(data.limit <= 200, `Limit must be clamped to max 200 (got ${data.limit})`);
  });

  await test('PAG 3.4: Exact boundary offset (offset = total - 1 and offset = total)', async () => {
    // Get total count
    const initRes = await fetchWithTimeout(`${BASE_URL}/api/history/list?limit=1`, { method: 'GET' }, TIMEOUT);
    const initData = await initRes.json();
    const total = initData.total;

    if (total > 0) {
      // offset = total - 1
      const resLast = await fetchWithTimeout(`${BASE_URL}/api/history/list?limit=10&offset=${total - 1}`, { method: 'GET' }, TIMEOUT);
      assertStatus(resLast, 200);
      const dataLast = await resLast.json();
      assertEqual(dataLast.items.length, 1, 'offset = total - 1 must return exactly 1 item');

      // offset = total
      const resEnd = await fetchWithTimeout(`${BASE_URL}/api/history/list?limit=10&offset=${total}`, { method: 'GET' }, TIMEOUT);
      assertStatus(resEnd, 200);
      const dataEnd = await resEnd.json();
      assertEqual(dataEnd.items.length, 0, 'offset = total must return empty array');
      assertEqual(dataEnd.total, total, 'total should remain accurate');
    }
  });

  await test('PAG 3.5: Non-numeric query parameters (limit=abc, offset=xyz)', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/history/list?limit=abc&offset=xyz`, { method: 'GET' }, TIMEOUT);
    assertStatus(res, 200);
    const data = await res.json();
    assertEqual(data.offset, 0, 'NaN offset must fallback to 0');
    assert(data.limit > 0, 'NaN limit must fallback to default limit');
    assert(Array.isArray(data.items), 'Items must be an array');
  });

  await test('PAG 3.6: Mode filter + pagination interaction (mode=calculus, limit=2, offset=0/2)', async () => {
    const resPage1 = await fetchWithTimeout(`${BASE_URL}/api/history/list?mode=calculus&limit=2&offset=0`, { method: 'GET' }, TIMEOUT);
    assertStatus(resPage1, 200);
    const page1 = await resPage1.json();
    for (const it of page1.items) {
      assertEqual(it.mode, 'calculus', 'All returned items must match mode=calculus');
    }

    if (page1.total > 2) {
      const resPage2 = await fetchWithTimeout(`${BASE_URL}/api/history/list?mode=calculus&limit=2&offset=2`, { method: 'GET' }, TIMEOUT);
      assertStatus(resPage2, 200);
      const page2 = await resPage2.json();
      for (const it of page2.items) {
        assertEqual(it.mode, 'calculus', 'Page 2 items must also match mode=calculus');
      }
      if (page1.items.length > 0 && page2.items.length > 0) {
        assert(page1.items[0].id !== page2.items[0].id, 'Page 1 and Page 2 must not have overlapping first item');
      }
    }
  });

  await test('PAG 3.7: Nonexistent mode filter (mode=unknown_mode_999)', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/history/list?mode=unknown_mode_999`, { method: 'GET' }, TIMEOUT);
    assertStatus(res, 200);
    const data = await res.json();
    assertEqual(data.count, 0, 'Count must be 0 for nonexistent mode');
    assertEqual(data.items.length, 0, 'Items must be empty');
  });

  await test('PAG 3.8: Search query with special regex characters (search=[3, 7] or search=*)', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/history/list?search=${encodeURIComponent('[3, 7]')}`, { method: 'GET' }, TIMEOUT);
    assertStatus(res, 200);
    const data = await res.json();
    assert(Array.isArray(data.items), 'Search with regex characters must not crash server');
  });
}

async function runUniversalCorsChallenges() {
  console.log('\n=== SECTION 4: UNIVERSAL CORS PREFLIGHT & HEADERS CHALLENGES ===');

  const routes = [
    { path: '/api/health', methods: ['GET', 'OPTIONS'] },
    { path: '/api/ai/stream', methods: ['POST', 'OPTIONS'] },
    { path: '/api/ai/solve', methods: ['POST', 'OPTIONS'] },
    { path: '/api/ota/manifest', methods: ['GET', 'OPTIONS'] },
    { path: '/api/ota/app', methods: ['GET', 'OPTIONS'] },
    { path: '/api/updates/check', methods: ['GET', 'OPTIONS'] },
    { path: '/api/updates/latest', methods: ['GET', 'OPTIONS'] },
    { path: '/api/history/sync', methods: ['POST', 'OPTIONS'] },
    { path: '/api/history/list', methods: ['GET', 'OPTIONS'] },
  ];

  const testOrigins = [
    'https://liquidcalc.app',
    'https://subdomain.liquidcalc.vercel.app',
    'http://localhost:8080',
    'http://127.0.0.1:3000',
    'capacitor://localhost',
    'ionic://localhost',
    'chrome-extension://mhjfbmdgcfjbbpaeojofohoefgiehjai',
    'null',
  ];

  for (const r of routes) {
    await test(`CORS Preflight: OPTIONS ${r.path} across diverse Origins`, async () => {
      for (const origin of testOrigins) {
        const res = await fetchWithTimeout(`${BASE_URL}${r.path}`, {
          method: 'OPTIONS',
          headers: {
            'Origin': origin,
            'Access-Control-Request-Method': r.methods[0],
            'Access-Control-Request-Headers': 'Content-Type, Authorization, x-gemini-api-key, X-Requested-With',
          },
        }, TIMEOUT);
        assert([200, 204].includes(res.status), `OPTIONS ${r.path} returned status ${res.status}`);
        
        const allowOrigin = res.headers.get('access-control-allow-origin');
        assert(allowOrigin === '*' || allowOrigin === origin, `Invalid Allow-Origin on ${r.path} (got ${allowOrigin})`);

        const allowMethods = res.headers.get('access-control-allow-methods');
        assert(allowMethods && allowMethods.includes('OPTIONS'), `Allow-Methods must include OPTIONS on ${r.path}`);

        const allowHeaders = res.headers.get('access-control-allow-headers');
        assert(allowHeaders && (allowHeaders.includes('Content-Type') || allowHeaders.includes('*')), `Allow-Headers must include Content-Type on ${r.path}`);
      }
    });
  }

  await test('CORS Headers: Verify actual GET/POST responses contain Access-Control-Allow-Origin', async () => {
    // 1. Health GET
    const resHealth = await fetchWithTimeout(`${BASE_URL}/api/health`, { method: 'GET' }, TIMEOUT);
    assertEqual(resHealth.headers.get('access-control-allow-origin'), '*', 'Health GET must have CORS header');

    // 2. Updates GET
    const resUpdates = await fetchWithTimeout(`${BASE_URL}/api/updates/check`, { method: 'GET' }, TIMEOUT);
    assertEqual(resUpdates.headers.get('access-control-allow-origin'), '*', 'Updates GET must have CORS header');

    // 3. OTA Manifest GET
    const resOta = await fetchWithTimeout(`${BASE_URL}/api/ota/manifest`, { method: 'GET' }, TIMEOUT);
    assertEqual(resOta.headers.get('access-control-allow-origin'), '*', 'OTA Manifest GET must have CORS header');

    // 4. History List GET
    const resList = await fetchWithTimeout(`${BASE_URL}/api/history/list`, { method: 'GET' }, TIMEOUT);
    assertEqual(resList.headers.get('access-control-allow-origin'), '*', 'History List GET must have CORS header');

    // 5. Solve POST
    const resSolve = await fetchWithTimeout(`${BASE_URL}/api/ai/solve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ mode: 'math', expression: '2+2' }),
    }, TIMEOUT);
    assertEqual(resSolve.headers.get('access-control-allow-origin'), '*', 'Solve POST must have CORS header');

    // 6. History Sync POST
    const resSync = await fetchWithTimeout(`${BASE_URL}/api/history/sync`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ items: [] }),
    }, TIMEOUT);
    assertEqual(resSync.headers.get('access-control-allow-origin'), '*', 'History Sync POST must have CORS header');
  });

  await test('CORS Complex Request Headers: Verify custom client headers supported in preflight', async () => {
    const complexHeaders = 'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization, x-gemini-api-key';
    const res = await fetchWithTimeout(`${BASE_URL}/api/ai/stream`, {
      method: 'OPTIONS',
      headers: {
        'Origin': 'https://custom-client.com',
        'Access-Control-Request-Method': 'POST',
        'Access-Control-Request-Headers': complexHeaders,
      },
    }, TIMEOUT);
    assert([200, 204].includes(res.status), `Preflight failed with status ${res.status}`);
    const allowHeaders = res.headers.get('access-control-allow-headers') || '';
    assert(allowHeaders.includes('x-gemini-api-key'), 'Access-Control-Allow-Headers must support x-gemini-api-key');
    assert(allowHeaders.includes('Authorization'), 'Access-Control-Allow-Headers must support Authorization');
  });
}

async function main() {
  console.log('╔══════════════════════════════════════════════════════════════════════╗');
  console.log('║   ⚡ EMPIRICAL CHALLENGER 2: DEEP STRESS & VERIFICATION SUITE ⚡    ║');
  console.log('╚══════════════════════════════════════════════════════════════════════╝');
  console.log(`Target: ${BASE_URL}\n`);

  await runMultimodalOcrChallenges();
  await runBatchHistorySyncChallenges();
  await runPaginationBoundaryChallenges();
  await runUniversalCorsChallenges();

  const total = results.passed + results.failed;
  const passRate = Math.round((results.passed / total) * 100);

  console.log('\n══════════════════════════════════════════════════════════════════════');
  console.log(`CHALLENGER 2 SUMMARY:`);
  console.log(`  Total Challenges: ${total}`);
  console.log(`  Passed:           ${results.passed}`);
  console.log(`  Failed:           ${results.failed}`);
  console.log(`  Pass Rate:        ${passRate}%`);
  console.log('══════════════════════════════════════════════════════════════════════\n');

  if (results.failed > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

main().catch((err) => {
  console.error('Fatal error in test suite:', err);
  process.exit(1);
});
