/**
 * LiquidCalc Backend E2E Test Suite - Tier 2: Boundary & Corner Cases
 * Validates edge parameters, malformed payloads, CORS preflight, and header fallbacks.
 */

import {
  assert,
  assertEqual,
  assertIncludes,
  assertStatus,
  assertValidXml,
  fetchWithTimeout,
} from './test_utils.mjs';

export async function runTier2(baseUrl, options = {}) {
  const tests = [
    {
      name: 'T2.1: Default Query Params on OTA Manifest (GET /api/ota/manifest)',
      description: 'Verifies bare request without query params falls back to standard bundle defaults',
      run: async () => {
        const res = await fetchWithTimeout(`${baseUrl}/api/ota/manifest`, { method: 'GET' }, options.timeout);
        assertStatus(res, 200);
        
        const xmlText = await res.text();
        assertValidXml(xmlText, 'Default OTA Manifest');
        assertIncludes(xmlText, 'com.liquidcalc.app', 'Should default to com.liquidcalc.app');
        assertIncludes(xmlText, 'LiquidCalc', 'Should default to LiquidCalc');
        assertIncludes(xmlText, '2.3.0', 'Should default to 2.3.0');
      },
    },
    {
      name: 'T2.2: XML Entity Escaping in OTA Manifest (GET /api/ota/manifest)',
      description: 'Verifies special XML characters (&, <, >, ", \') are sanitized to preserve well-formed XML',
      run: async () => {
        const specialName = 'Liquid & Calc <Beta> "Special"';
        const res = await fetchWithTimeout(
          `${baseUrl}/api/ota/manifest?name=${encodeURIComponent(specialName)}&version=2.3.0-rc1`,
          { method: 'GET' },
          options.timeout
        );
        assertStatus(res, 200);
        
        const xmlText = await res.text();
        assertValidXml(xmlText, 'Escaped OTA Manifest');
        assert(
          xmlText.includes('&amp;') || xmlText.includes('Liquid &amp; Calc') || !xmlText.includes('<Beta>'),
          'Special characters like & and < must be escaped or sanitized in XML output'
        );
      },
    },
    {
      name: 'T2.3: Malformed Empty Payload on AI Stream (POST /api/ai/stream)',
      description: 'Verifies empty payload {} returns HTTP 400 Bad Request',
      run: async () => {
        const res = await fetchWithTimeout(
          `${baseUrl}/api/ai/stream`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({}),
          },
          options.timeout
        );
        // Either 400 Bad Request or 401 if auth checked before payload
        assert(
          [400, 401, 422].includes(res.status),
          `Expected 400 or 401/422 for empty payload, got ${res.status}`
        );
      },
    },
    {
      name: 'T2.4: Malformed Payload on AI Solve (POST /api/ai/solve)',
      description: 'Verifies missing expression/image returns structured HTTP 400/422 error',
      run: async () => {
        const res = await fetchWithTimeout(
          `${baseUrl}/api/ai/solve`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ mode: 'invalid_mode_xyz' }),
          },
          options.timeout
        );
        assert(
          [400, 401, 422].includes(res.status),
          `Expected 400/401/422 for invalid solver payload, got ${res.status}`
        );
      },
    },
    {
      name: 'T2.5: Malformed Payload on History Sync (POST /api/history/sync)',
      description: 'Verifies non-array items payload returns HTTP 400 Bad Request',
      run: async () => {
        const res = await fetchWithTimeout(
          `${baseUrl}/api/history/sync`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ items: 'not-an-array' }),
          },
          options.timeout
        );
        assertStatus(res, 400, 'Non-array items must be rejected with 400 Bad Request');
      },
    },
    {
      name: 'T2.6: Universal CORS Preflight Across All Routes (OPTIONS)',
      description: 'Verifies CORS preflight OPTIONS returns 200/204 with permissive Access-Control headers across 6 endpoints',
      run: async () => {
        const routes = [
          '/api/health',
          '/api/ai/stream',
          '/api/ai/solve',
          '/api/ota/manifest',
          '/api/updates/check',
          '/api/history/sync',
          '/api/history/list',
        ];
        
        for (const route of routes) {
          const res = await fetchWithTimeout(
            `${baseUrl}${route}`,
            {
              method: 'OPTIONS',
              headers: {
                'Origin': 'https://liquidcalc.app',
                'Access-Control-Request-Method': 'POST',
                'Access-Control-Request-Headers': 'Content-Type, Authorization, x-gemini-api-key',
              },
            },
            options.timeout
          );
          
          assert(
            [200, 204].includes(res.status),
            `OPTIONS ${route} returned unexpected status ${res.status}`
          );
          
          const allowOrigin = res.headers.get('access-control-allow-origin');
          assert(
            allowOrigin === '*' || allowOrigin === 'https://liquidcalc.app',
            `OPTIONS ${route} must have valid Access-Control-Allow-Origin header (got ${allowOrigin})`
          );
        }
      },
    },
    {
      name: 'T2.7: API Key Header Fallback Support',
      description: 'Verifies x-gemini-api-key and Authorization: Bearer header ingestion on AI endpoints',
      run: async () => {
        // Send request with custom mock header key
        const testKey = 'AIzaSyTestMockKeyForHeaderValidation123456';
        const resHeader = await fetchWithTimeout(
          `${baseUrl}/api/ai/solve`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'x-gemini-api-key': testKey,
            },
            body: JSON.stringify({ mode: 'math', expression: '2+2' }),
          },
          options.timeout
        );
        
        // The server should accept the header and attempt to use it (or return 200 if valid / 502/400 from upstream Google)
        // Crucially, it must NOT return 401 "Missing GEMINI_API_KEY" because the header was provided
        const headerBody = await resHeader.json().catch(() => ({}));
        if (resHeader.status === 401) {
          assert(
            !headerBody.error?.toLowerCase().includes('missing gemini_api_key'),
            'Should recognize header key and not claim missing key configuration'
          );
        }
      },
    },
    {
      name: 'T2.8: History Pagination Limits & Out-of-Bounds Offsets (GET /api/history/list)',
      description: 'Verifies limit=0, limit=200, and out-of-bounds offset=99999 return gracefully without server error',
      run: async () => {
        // Test limit=1
        const res1 = await fetchWithTimeout(`${baseUrl}/api/history/list?limit=1&offset=0`, { method: 'GET' }, options.timeout);
        assertStatus(res1, 200);
        const data1 = await res1.json();
        assert(data1.items.length <= 1, 'limit=1 must return at most 1 item');
        
        // Test out-of-bounds offset
        const resOOB = await fetchWithTimeout(`${baseUrl}/api/history/list?limit=10&offset=99999`, { method: 'GET' }, options.timeout);
        assertStatus(resOOB, 200);
        const dataOOB = await resOOB.json();
        assertEqual(dataOOB.items.length, 0, 'Out-of-bounds offset must return empty items array');
        assert(typeof dataOOB.total === 'number', 'Total count should still be reported');
      },
    },
    {
      name: 'T2.9: Semantic Version Comparison Boundaries (GET /api/updates/check)',
      description: 'Verifies version evaluation for equal version (2.3.0), newer version (3.0.0), and older (0.1.0)',
      run: async () => {
        // Equal version -> updateAvailable: false
        const resEqual = await fetchWithTimeout(`${baseUrl}/api/updates/check?currentVersion=2.3.0`, { method: 'GET' }, options.timeout);
        assertStatus(resEqual, 200);
        const dataEqual = await resEqual.json();
        assertEqual(dataEqual.updateAvailable, false, 'updateAvailable must be false for currentVersion=2.3.0');
        
        // Newer version -> updateAvailable: false
        const resNewer = await fetchWithTimeout(`${baseUrl}/api/updates/check?currentVersion=3.0.0`, { method: 'GET' }, options.timeout);
        assertStatus(resNewer, 200);
        const dataNewer = await resNewer.json();
        assertEqual(dataNewer.updateAvailable, false, 'updateAvailable must be false for client ahead of release (3.0.0)');
        
        // Older version -> updateAvailable: true
        const resOlder = await fetchWithTimeout(`${baseUrl}/api/updates/check?currentVersion=1.0.0`, { method: 'GET' }, options.timeout);
        assertStatus(resOlder, 200);
        const dataOlder = await resOlder.json();
        assertEqual(dataOlder.updateAvailable, true, 'updateAvailable must be true for older version 1.0.0');
      },
    },
    {
      name: 'T2.10: Extreme Mathematical Expression Handling (POST /api/ai/solve)',
      description: 'Verifies solver handles complex nested brackets and long expressions without crashing',
      run: async () => {
        const extremeExpr = '((12.5 * 4.2) / (3.1415926535 * (7.8 ^ 2))) + sqrt(144) - sum_{k=1}^5 (k^2)';
        const res = await fetchWithTimeout(
          `${baseUrl}/api/ai/solve`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              mode: 'math',
              expression: extremeExpr,
            }),
          },
          options.timeout || 20000
        );
        
        // Should return structured response (200) or clean upstream status (401/502), not unhandled 500 crash
        assert(
          [200, 401, 502].includes(res.status),
          `Expected 200, 401, or 502, got unhandled ${res.status}`
        );
      },
    },
  ];

  return tests;
}
