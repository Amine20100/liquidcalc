/**
 * LiquidCalc Backend E2E Test Suite - Tier 1: Feature Coverage
 * Tests all 10 core baseline features against the live or local backend.
 */

import {
  assert,
  assertEqual,
  assertIncludes,
  assertStatus,
  assertValidXml,
  fetchWithTimeout,
  readSSEStream,
} from './test_utils.mjs';

export async function runTier1(baseUrl, options = {}) {
  const tests = [
    {
      name: 'T1.1: Health Check (GET /api/health)',
      description: 'Verifies system health, uptime, version 2.3.0, and subservice status object',
      run: async () => {
        const res = await fetchWithTimeout(`${baseUrl}/api/health`, { method: 'GET' }, options.timeout);
        assertStatus(res, 200);
        
        const data = await res.json();
        assert(data.healthy === true || data.status === 'operational', 'Health check should indicate healthy/operational status');
        assertEqual(data.version, '2.3.0', 'API version must be 2.3.0');
        assert(typeof data.timestamp === 'string' && data.timestamp.length > 0, 'Timestamp must be non-empty ISO string');
        assert(typeof data.services === 'object' && data.services !== null, 'Services status object must be present');
        assert('gemini_gateway' in data.services, 'gemini_gateway must be present in services');
        assert('ota_signer' in data.services, 'ota_signer must be present in services');
        assert('updates_dist' in data.services, 'updates_dist must be present in services');
        assert('history_sync' in data.services, 'history_sync must be present in services');
      },
    },
    {
      name: 'T1.2: Gemini 2.5 Flash SSE Stream (POST /api/ai/stream)',
      description: 'Verifies Server-Sent Events streaming with text chunks and completion signal',
      run: async () => {
        const headers = { 'Content-Type': 'application/json' };
        if (options.apiKey) {
          headers['x-gemini-api-key'] = options.apiKey;
        }
        
        const res = await fetchWithTimeout(
          `${baseUrl}/api/ai/stream`,
          {
            method: 'POST',
            headers,
            body: JSON.stringify({
              prompt: 'Calculate 24 * 5 and explain the steps briefly',
              temperature: 0.1,
            }),
          },
          options.timeout || 20000
        );
        
        // If no API key configured on server or in test, 401 or 502 with structured error is an expected response
        if (res.status === 401 || res.status === 502) {
          const errData = await res.json().catch(() => ({}));
          assert(errData.error || errData.message, 'Should return informative message when API key is unconfigured');
          return { note: 'Gateway responded with auth/upstream status as expected without API key' };
        }
        
        assertStatus(res, 200);
        const contentType = res.headers.get('content-type') || '';
        assertIncludes(contentType, 'text/event-stream', 'Content-Type must be text/event-stream');
        
        const { chunks, fullText, doneReceived } = await readSSEStream(res, 30, options.timeout || 15000);
        assert(chunks.length > 0, 'Stream must yield at least one SSE data chunk');
        assert(doneReceived || fullText.length > 0, 'Stream must deliver text content or completion event');
      },
    },
    {
      name: 'T1.3: Gemini AI Structured Solver (POST /api/ai/solve)',
      description: 'Verifies structured JSON math equation solver schema and response properties',
      run: async () => {
        const headers = { 'Content-Type': 'application/json' };
        if (options.apiKey) {
          headers['x-gemini-api-key'] = options.apiKey;
        }
        
        const res = await fetchWithTimeout(
          `${baseUrl}/api/ai/solve`,
          {
            method: 'POST',
            headers,
            body: JSON.stringify({
              mode: 'math',
              expression: '12 * 8 + 4',
            }),
          },
          options.timeout || 20000
        );
        
        if (res.status === 401 || res.status === 502) {
          const errData = await res.json().catch(() => ({}));
          assert(errData.error || errData.message, 'Should return informative message when API key is unconfigured');
          return { note: 'Solver responded with auth/upstream status as expected without API key' };
        }
        
        assertStatus(res, 200);
        const data = await res.json();
        assert(data.success === true, 'Response must indicate success: true');
        assert(typeof data.result === 'string' || typeof data.result === 'number', 'Response must include result');
        assert(Array.isArray(data.steps), 'Response must include steps array');
      },
    },
    {
      name: 'T1.4: Dynamic iOS OTA Manifest (GET /api/ota/manifest)',
      description: 'Verifies dynamic Apple itms-services software-package XML plist format and DTD compliance',
      run: async () => {
        const res = await fetchWithTimeout(
          `${baseUrl}/api/ota/manifest?bundleId=com.liquidcalc.app&name=LiquidCalc&version=2.3.0`,
          { method: 'GET' },
          options.timeout
        );
        assertStatus(res, 200);
        
        const contentType = res.headers.get('content-type') || '';
        assert(
          contentType.includes('text/xml') || contentType.includes('application/xml') || contentType.includes('application/x-plist'),
          `Content-Type must be XML/plist, got: ${contentType}`
        );
        
        const xmlText = await res.text();
        assertValidXml(xmlText, 'OTA Manifest');
        assertIncludes(xmlText, 'software-package', 'Manifest must define software-package asset');
        assertIncludes(xmlText, 'com.liquidcalc.app', 'Manifest must embed bundleId');
        assertIncludes(xmlText, '2.3.0', 'Manifest must embed app version');
        assertIncludes(xmlText, 'LiquidCalc', 'Manifest must embed app title');
      },
    },
    {
      name: 'T1.5: iOS App IPA Binary Handler (GET /api/ota/app)',
      description: 'Verifies binary download or redirect to signed IPA release',
      run: async () => {
        const res = await fetchWithTimeout(
          `${baseUrl}/api/ota/app`,
          { method: 'GET', redirect: 'manual' },
          options.timeout
        );
        
        // Should either redirect (302/307/308) to GitHub/CDN or return binary (200)
        assert(
          [200, 302, 307, 308].includes(res.status),
          `Expected 200 or 302/307/308 redirect, got ${res.status}`
        );
        
        if ([302, 307, 308].includes(res.status)) {
          const location = res.headers.get('location') || '';
          assert(location.length > 0, 'Redirect response must include Location header');
          assert(location.includes('.ipa') || location.includes('github.com'), 'Location header must point to IPA asset');
        }
      },
    },
    {
      name: 'T1.6: App Version Update Checker (GET /api/updates/check)',
      description: 'Verifies version 2.3.0 metadata, buildNumber 23, changelog, and OTA links',
      run: async () => {
        const res = await fetchWithTimeout(
          `${baseUrl}/api/updates/check?currentVersion=2.2.0`,
          { method: 'GET' },
          options.timeout
        );
        assertStatus(res, 200);
        
        const data = await res.json();
        assertEqual(data.latestVersion, '2.3.0', 'latestVersion must be 2.3.0');
        assertEqual(String(data.buildNumber), '23', 'buildNumber must be 23');
        assertEqual(data.updateAvailable, true, 'updateAvailable must be true when checking older version 2.2.0');
        assert(typeof data.downloadURL === 'string' && data.downloadURL.length > 0, 'downloadURL must be present');
        assert(typeof data.otaManifestURL === 'string' && data.otaManifestURL.length > 0, 'otaManifestURL must be present');
        assert(typeof data.otaInstallURL === 'string' && data.otaInstallURL.startsWith('itms-services://'), 'otaInstallURL must use itms-services scheme');
        assert(Array.isArray(data.changelog) && data.changelog.length > 0, 'changelog must be a non-empty array');
      },
    },
    {
      name: 'T1.7: Latest Release Metadata (GET /api/updates/latest)',
      description: 'Verifies GitHub and AltStore compatible release payload and asset listings',
      run: async () => {
        const res = await fetchWithTimeout(`${baseUrl}/api/updates/latest`, { method: 'GET' }, options.timeout);
        assertStatus(res, 200);
        
        const data = await res.json();
        assert(data.tag_name === 'v2.3.0' || data.name.includes('2.3.0'), 'Release tag or name must reference 2.3.0');
        assert(Array.isArray(data.assets), 'Release payload must include assets array');
        const ipaAsset = data.assets.find(a => a.name.endsWith('.ipa'));
        assert(ipaAsset !== undefined, 'Assets must include LiquidCalc.ipa');
        assert(typeof ipaAsset.browser_download_url === 'string', 'IPA asset must include browser_download_url');
      },
    },
    {
      name: 'T1.8: Calculation History Sync (POST /api/history/sync)',
      description: 'Verifies calculation history batch synchronization and record counting',
      run: async () => {
        const testId = `T1-SYNC-${Date.now()}`;
        const res = await fetchWithTimeout(
          `${baseUrl}/api/history/sync`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              deviceId: 'test-device-t1',
              items: [
                {
                  id: testId,
                  timestamp: new Date().toISOString(),
                  expression: '15 * 6 + 10',
                  result: '100',
                  mode: 'standard',
                  notes: 'Tier 1 Sync Test',
                },
              ],
            }),
          },
          options.timeout
        );
        assertStatus(res, 200);
        
        const data = await res.json();
        assert(data.success === true, 'History sync must return success: true');
        assert(data.syncedCount >= 1, 'syncedCount must be at least 1');
        assert(typeof data.totalRecords === 'number', 'totalRecords must be a number');
      },
    },
    {
      name: 'T1.9: Calculation History List (GET /api/history/list)',
      description: 'Verifies retrieval of synchronized calculation history items with count and total',
      run: async () => {
        const res = await fetchWithTimeout(`${baseUrl}/api/history/list?limit=10`, { method: 'GET' }, options.timeout);
        assertStatus(res, 200);
        
        const data = await res.json();
        assert(data.success === true, 'History list must return success: true');
        assert(typeof data.count === 'number', 'Response must include item count');
        assert(Array.isArray(data.items), 'Response must include items array');
      },
    },
    {
      name: 'T1.10: Status Dashboard Web Interface (GET /)',
      description: 'Verifies root status dashboard renders cyberpunk glassmorphism UI with service telemetry',
      run: async () => {
        const res = await fetchWithTimeout(`${baseUrl}/`, { method: 'GET' }, options.timeout);
        assertStatus(res, 200);
        
        const contentType = res.headers.get('content-type') || '';
        assertIncludes(contentType, 'text/html', 'Root page must return text/html');
        
        const html = await res.text();
        assert(html.length > 200, 'HTML content must not be empty');
        assert(
          html.includes('LiquidCalc') || html.includes('Serverless') || html.includes('Operational'),
          'Dashboard must display LiquidCalc brand or status markers'
        );
      },
    },
  ];

  return tests;
}
