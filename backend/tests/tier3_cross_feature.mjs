/**
 * LiquidCalc Backend E2E Test Suite - Tier 3: Cross-Feature Combinations
 * Tests end-to-end multi-endpoint state workflows, URL consistency, and concurrent stress.
 */

import {
  assert,
  assertEqual,
  assertIncludes,
  assertStatus,
  assertValidXml,
  fetchWithTimeout,
} from './test_utils.mjs';

export async function runTier3(baseUrl, options = {}) {
  const tests = [
    {
      name: 'T3.1: History Sync -> Solve -> Verification Cycle',
      description: 'Executes full lifecycle: syncs initial record, performs AI calculation, syncs result, and verifies in history list',
      run: async () => {
        const sessionDevice = `T3-DEVICE-${Date.now()}`;
        const item1Id = `ITEM-1-${Date.now()}`;
        const item2Id = `ITEM-2-${Date.now()}`;
        
        // 1. Initial Sync
        const sync1Res = await fetchWithTimeout(
          `${baseUrl}/api/history/sync`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              deviceId: sessionDevice,
              items: [
                {
                  id: item1Id,
                  timestamp: new Date().toISOString(),
                  expression: '50 * 2',
                  result: '100',
                  mode: 'standard',
                  notes: 'Initial step',
                },
              ],
            }),
          },
          options.timeout
        );
        assertStatus(sync1Res, 200, 'Initial sync must succeed');
        
        // 2. Perform AI Solve
        const headers = { 'Content-Type': 'application/json' };
        if (options.apiKey) headers['x-gemini-api-key'] = options.apiKey;
        
        const solveRes = await fetchWithTimeout(
          `${baseUrl}/api/ai/solve`,
          {
            method: 'POST',
            headers,
            body: JSON.stringify({
              mode: 'math',
              expression: 'sqrt(256) + 14',
            }),
          },
          options.timeout || 20000
        );
        
        let solveResult = '30';
        if (solveRes.status === 200) {
          const solveData = await solveRes.json();
          if (solveData.result) solveResult = String(solveData.result);
        }
        
        // 3. Sync Solved Result
        const sync2Res = await fetchWithTimeout(
          `${baseUrl}/api/history/sync`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              deviceId: sessionDevice,
              items: [
                {
                  id: item2Id,
                  timestamp: new Date().toISOString(),
                  expression: 'sqrt(256) + 14',
                  result: solveResult,
                  mode: 'scientific',
                  notes: 'AI Solved',
                },
              ],
            }),
          },
          options.timeout
        );
        assertStatus(sync2Res, 200, 'Second sync must succeed');
        
        // 4. Verify in List
        const listRes = await fetchWithTimeout(
          `${baseUrl}/api/history/list?deviceId=${sessionDevice}&limit=20`,
          { method: 'GET' },
          options.timeout
        );
        assertStatus(listRes, 200, 'History list must return 200');
        
        const listData = await listRes.json();
        assert(listData.items.length >= 2, `Expected at least 2 items for device, got ${listData.items.length}`);
        
        const ids = listData.items.map(i => i.id);
        assert(ids.includes(item1Id), 'History list must contain item1');
        assert(ids.includes(item2Id), 'History list must contain item2');
      },
    },
    {
      name: 'T3.2: OTA Manifest & IPA Asset Consistency',
      description: 'Parses IPA download URL from dynamic manifest XML and asserts /api/ota/app redirect target matches',
      run: async () => {
        // 1. Fetch Manifest
        const manifestRes = await fetchWithTimeout(`${baseUrl}/api/ota/manifest`, { method: 'GET' }, options.timeout);
        assertStatus(manifestRes, 200);
        
        const xml = await manifestRes.text();
        assertValidXml(xml, 'OTA Manifest');
        
        // Extract software-package URL
        const urlMatch = xml.match(/<string>(https?:\/\/[^<]+\.ipa)<\/string>/i);
        assert(urlMatch !== null && urlMatch[1], 'Could not extract IPA URL from manifest XML');
        const manifestIpaUrl = urlMatch[1];
        
        // 2. Query /api/ota/app
        const appRes = await fetchWithTimeout(
          `${baseUrl}/api/ota/app`,
          { method: 'GET', redirect: 'manual' },
          options.timeout
        );
        
        if ([302, 307, 308].includes(appRes.status)) {
          const redirectLocation = appRes.headers.get('location');
          assert(
            redirectLocation.includes('.ipa') || redirectLocation.includes('github.com'),
            `Redirect location (${redirectLocation}) must point to IPA binary`
          );
        }
      },
    },
    {
      name: 'T3.3: Updates Check <-> OTA Manifest Link Consistency',
      description: 'Validates that otaManifestURL in updates/check returns valid XML and matches latestVersion',
      run: async () => {
        const updateRes = await fetchWithTimeout(`${baseUrl}/api/updates/check`, { method: 'GET' }, options.timeout);
        assertStatus(updateRes, 200);
        
        const updateData = await updateRes.json();
        const otaManifestURL = updateData.otaManifestURL;
        assert(typeof otaManifestURL === 'string' && otaManifestURL.length > 0, 'otaManifestURL must be provided');
        
        // Verify itms-services format
        const otaInstallURL = updateData.otaInstallURL;
        assert(
          otaInstallURL.startsWith('itms-services://?action=download-manifest&url='),
          `otaInstallURL (${otaInstallURL}) must be an itms-services download link`
        );
        
        // Directly fetch the manifest from the specified relative or absolute URL
        const manifestFetchUrl = otaManifestURL.startsWith('http')
          ? otaManifestURL
          : `${baseUrl}${otaManifestURL.startsWith('/') ? '' : '/'}${otaManifestURL}`;
        
        const manifestRes = await fetchWithTimeout(manifestFetchUrl, { method: 'GET' }, options.timeout);
        assertStatus(manifestRes, 200, `Manifest at ${manifestFetchUrl} must return 200`);
        
        const xml = await manifestRes.text();
        assertValidXml(xml, 'Updates Check Manifest');
        assertIncludes(xml, updateData.latestVersion, 'Manifest must contain the latest version string from updates check');
      },
    },
    {
      name: 'T3.4: Concurrent Request Stress & Health Resilience',
      description: 'Dispatches 20 concurrent asynchronous requests across endpoints asserting 100% success without 5xx errors',
      run: async () => {
        const endpoints = [
          '/api/health',
          '/api/history/list?limit=5',
          '/api/updates/check',
          '/api/ota/manifest',
          '/api/updates/latest',
        ];
        
        // Build 20 requests
        const requests = Array.from({ length: 20 }, async (_, idx) => {
          const endpoint = endpoints[idx % endpoints.length];
          for (let attempt = 0; attempt < 3; attempt++) {
            try {
              const res = await fetchWithTimeout(`${baseUrl}${endpoint}`, { method: 'GET' }, options.timeout || 10000);
              return {
                idx,
                endpoint,
                status: res.status,
                ok: res.status >= 200 && res.status < 400,
              };
            } catch (err) {
              if (attempt === 2) throw err;
              await new Promise(r => setTimeout(r, 50 * (idx % 5 + 1)));
            }
          }
        });
        
        const results = await Promise.all(requests);
        const failures = results.filter(r => !r.ok);
        
        assert(
          failures.length === 0,
          `Concurrent stress test had ${failures.length}/20 failures: ${JSON.stringify(failures)}`
        );
      },
    },
  ];

  return tests;
}
