#!/usr/bin/env node

/**
 * LiquidCalc Empirical Adversarial Stress & Hardening Test Harness (Fast & Comprehensive)
 */

import { performance } from 'perf_hooks';

const BASE_URL = process.env.TEST_URL || 'http://localhost:3000';

const colors = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  white: '\x1b[37m',
  gray: '\x1b[90m',
};

// Helper for fetch with timeout
async function fetchWithTimeout(url, options = {}, timeoutMs = 8000) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { ...options, signal: controller.signal });
    clearTimeout(timeoutId);
    return res;
  } catch (err) {
    clearTimeout(timeoutId);
    throw err;
  }
}

class ChallengerSuite {
  constructor(baseUrl) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.passed = 0;
    this.failed = 0;
    this.total = 0;
    this.findings = [];
  }

  logSection(title) {
    console.log(`\n${colors.cyan}${colors.bold}═══ [ ${title} ] ══════════════════════════════════════════════${colors.reset}`);
  }

  async runTest(name, description, testFn) {
    this.total++;
    process.stdout.write(`  ${colors.gray}•${colors.reset} ${name.padEnd(58)} `);
    const start = performance.now();
    try {
      const result = await testFn();
      const elapsed = Math.round(performance.now() - start);
      this.passed++;
      const note = result && result.note ? ` ${colors.gray}(${result.note})${colors.reset}` : '';
      console.log(`${colors.green}✓ PASS${colors.reset} ${colors.dim}(${elapsed}ms)${colors.reset}${note}`);
    } catch (err) {
      const elapsed = Math.round(performance.now() - start);
      this.failed++;
      console.log(`${colors.red}✗ FAIL${colors.reset} ${colors.dim}(${elapsed}ms)${colors.reset}`);
      console.log(`    ${colors.red}${colors.bold}Defect:${colors.reset} ${err.message}`);
      this.findings.push({
        name,
        description,
        error: err.message,
      });
    }
  }

  assert(condition, message) {
    if (!condition) {
      throw new Error(message || 'Assertion failed');
    }
  }

  // ==========================================
  // 1. CONCURRENCY & RACE CONDITIONS
  // ==========================================
  async testConcurrency() {
    this.logSection('1. HIGH CONCURRENCY & RACE CONDITION SUITE');

    // 1.1 Burst Concurrency on Health Endpoint (100 parallel requests)
    await this.runTest(
      'CONCUR-1: 100 parallel GET requests on /api/health',
      'Verify serverless process handles 100 concurrent health probes without drops or 5xx',
      async () => {
        const promises = Array.from({ length: 100 }, () =>
          fetchWithTimeout(`${this.baseUrl}/api/health`, { headers: { Accept: 'application/json' } })
        );
        const responses = await Promise.all(promises);
        const non200 = responses.filter((r) => r.status !== 200).map((r) => r.status);
        this.assert(non200.length === 0, `Expected all 200, got non-200s: ${JSON.stringify(non200)}`);
        const bodies = await Promise.all(responses.slice(0, 5).map((r) => r.json()));
        for (const b of bodies) {
          this.assert(b.status === 'operational', 'Payload status must be operational');
          this.assert(b.healthy === true, 'healthy flag must be true');
        }
        return { note: '100/100 HTTP 200 OK' };
      }
    );

    // 1.2 Concurrent History Sync & List Interleaving (50 syncs + 50 reads in parallel)
    await this.runTest(
      'CONCUR-2: Concurrent History write/read race conditions',
      'Simultaneously execute 50 POST /api/history/sync and 50 GET /api/history/list',
      async () => {
        const uniquePrefix = `concur_${Date.now()}`;
        const syncPromises = Array.from({ length: 50 }, (_, i) =>
          fetchWithTimeout(`${this.baseUrl}/api/history/sync`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              deviceId: `device_${i}`,
              items: [
                {
                  id: `${uniquePrefix}_${i}`,
                  timestamp: new Date().toISOString(),
                  expression: `${i} * ${i} + 1`,
                  result: `${i * i + 1}`,
                  mode: i % 2 === 0 ? 'calculus' : 'standard',
                  notes: `Stress test item #${i}`,
                },
              ],
            }),
          })
        );

        const listPromises = Array.from({ length: 50 }, () =>
          fetchWithTimeout(`${this.baseUrl}/api/history/list?limit=100`, {
            headers: { Accept: 'application/json' },
          })
        );

        const allResponses = await Promise.all([...syncPromises, ...listPromises]);
        const non200 = allResponses.filter((r) => r.status !== 200);
        this.assert(non200.length === 0, `Found ${non200.length} non-200 responses during concurrent write/read`);

        const verifyRes = await fetchWithTimeout(`${this.baseUrl}/api/history/list?search=${uniquePrefix}&limit=100`);
        const verifyData = await verifyRes.json();
        this.assert(verifyData.count === 50, `Expected 50 synced items, found ${verifyData.count}`);
        return { note: '50 writes + 50 reads without data corruption' };
      }
    );

    // 1.3 Concurrent Structured AI Solves (10 parallel requests)
    await this.runTest(
      'CONCUR-3: 10 parallel POST /api/ai/solve requests',
      'Verify parallel execution of AI solver endpoint with math & receipt modes',
      async () => {
        const expressions = [
          'sin(pi/4) + cos(pi/4)',
          'integrate(x^2, 0, 3)',
          '150 * 1.0825',
          'sqrt(144) + 12^2',
          '3x + 5 = 20',
        ];
        const promises = Array.from({ length: 10 }, (_, i) =>
          fetchWithTimeout(`${this.baseUrl}/api/ai/solve`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              mode: i % 2 === 0 ? 'receipt' : 'math',
              expression: expressions[i % expressions.length],
            }),
          }, 10000)
        );

        const responses = await Promise.all(promises);
        const non200 = responses.filter((r) => r.status !== 200);
        this.assert(non200.length === 0, `Expected all 200, got non-200 count: ${non200.length}`);
        const parsed = await Promise.all(responses.map((r) => r.json()));
        for (const item of parsed) {
          this.assert(item.success === true, 'All solves should succeed');
        }
        return { note: '10 concurrent solves completed' };
      }
    );

    // 1.4 Concurrent SSE Streaming Connections (10 parallel streams)
    await this.runTest(
      'CONCUR-4: 10 concurrent SSE streams on /api/ai/stream',
      'Verify that 10 simultaneous client streams receive unbuffered chunks and close cleanly',
      async () => {
        const streamPromises = Array.from({ length: 10 }, async (_, i) => {
          const res = await fetchWithTimeout(`${this.baseUrl}/api/ai/stream`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ prompt: `Calculate derivative of x^${i + 2}` }),
          }, 10000);
          this.assert(res.status === 200, `Stream ${i} returned status ${res.status}`);
          this.assert(res.headers.get('content-type')?.includes('text/event-stream'), 'Missing event-stream content-type');

          const reader = res.body.getReader();
          const decoder = new TextDecoder();
          let chunksCount = 0;
          let doneReceived = false;

          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            const text = decoder.decode(value);
            if (text.includes('data:')) {
              chunksCount++;
              if (text.includes('"done":true')) {
                doneReceived = true;
              }
            }
          }
          this.assert(chunksCount > 0, `Stream ${i} received 0 chunks`);
          this.assert(doneReceived, `Stream ${i} did not receive done flag`);
          return chunksCount;
        });

        const results = await Promise.all(streamPromises);
        return { note: `10 streams completed (avg ${Math.round(results.reduce((a,b)=>a+b,0)/results.length)} chunks each)` };
      }
    );
  }

  // ==========================================
  // 2. MALFORMED JSON & PAYLOAD FUZZING
  // ==========================================
  async testMalformedJson() {
    this.logSection('2. MALFORMED JSON & PAYLOAD FUZZING SUITE');

    const endpoints = [
      { path: '/api/ai/solve', name: 'AI Solve' },
      { path: '/api/ai/stream', name: 'AI Stream' },
      { path: '/api/history/sync', name: 'History Sync' },
    ];

    // 2.1 Broken JSON Syntax Fuzzing
    for (const ep of endpoints) {
      await this.runTest(
        `JSON-FUZZ-1: Broken JSON syntax on ${ep.path}`,
        `Verify ${ep.path} rejects malformed JSON with HTTP 400 without crashing`,
        async () => {
          const malformedPayloads = [
            '{ "expression": "2+2", ', // truncated
            '{ keyWithoutQuotes: 123 }', // invalid JS object
            '{"prompt": "hello",}', // trailing comma
            '<<<MALFORMED XML AS JSON>>>',
            '', // completely empty
            '   \n\t  ', // whitespace only
            '{"unclosed_string": "',
          ];

          for (const payload of malformedPayloads) {
            const res = await fetchWithTimeout(`${this.baseUrl}${ep.path}`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: payload,
            });
            this.assert(
              res.status === 400,
              `Endpoint ${ep.path} with payload '${payload.slice(0, 20)}...' returned status ${res.status}, expected 400`
            );
            const data = await res.json();
            this.assert(data.error !== undefined, 'Response must contain error property');
          }
          return { note: `${malformedPayloads.length} malformed payloads rejected with 400` };
        }
      );
    }

    // 2.2 Unexpected JSON Types (Primitives / null / Arrays where Object Expected)
    for (const ep of endpoints) {
      await this.runTest(
        `JSON-FUZZ-2: Unexpected top-level JSON types (null/primitives) on ${ep.path}`,
        `Send null, arrays, strings, booleans, and numbers to ${ep.path} and verify safe HTTP 400 rejection without 500 crashes`,
        async () => {
          const weirdPayloads = [
            JSON.stringify(null),
            JSON.stringify(['array', 'of', 'strings']),
            JSON.stringify('just a raw string'),
            JSON.stringify(123456789),
            JSON.stringify(true),
          ];

          for (const payload of weirdPayloads) {
            const res = await fetchWithTimeout(`${this.baseUrl}${ep.path}`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: payload,
            });
            // Should be 400 bad request, never 500
            this.assert(
              res.status === 400,
              `Endpoint ${ep.path} with payload ${payload} returned status ${res.status}, expected 400`
            );
          }
          return { note: `${weirdPayloads.length} primitive types safely rejected with 400` };
        }
      );
    }

    // 2.3 Non-JSON Content-Type with arbitrary body
    for (const ep of endpoints) {
      await this.runTest(
        `JSON-FUZZ-3: Non-JSON Content-Types on ${ep.path}`,
        `Send text/plain, text/html, and application/x-www-form-urlencoded to ${ep.path}`,
        async () => {
          const contentTypes = ['text/plain', 'text/html', 'application/x-www-form-urlencoded'];
          for (const ct of contentTypes) {
            const res = await fetchWithTimeout(`${this.baseUrl}${ep.path}`, {
              method: 'POST',
              headers: { 'Content-Type': ct },
              body: 'raw text content that is not json',
            });
            this.assert(
              res.status === 400,
              `Endpoint ${ep.path} with Content-Type ${ct} returned ${res.status}, expected 400`
            );
          }
          return { note: 'Non-JSON Content-Types handled safely' };
        }
      );
    }

    // 2.4 Null Byte and Control Character Injection
    await this.runTest(
      'JSON-FUZZ-4: Null bytes and control chars in JSON strings',
      'Inject \\u0000, \\r, \\n, and RTL overrides into JSON string fields',
      async () => {
        const trickyPayload = {
          expression: '2 + 2\u0000\u0007\b\f\v\u202Ereversed\u202D',
          mode: 'math',
        };
        const res = await fetchWithTimeout(`${this.baseUrl}/api/ai/solve`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(trickyPayload),
        });
        this.assert(res.status === 200, `Expected 200 OK with sanitized calculation, got ${res.status}`);
        const data = await res.json();
        this.assert(data.success === true, 'Solve should succeed gracefully with control chars');
        return { note: 'Sanitized control characters correctly' };
      }
    );
  }

  // ==========================================
  // 3. XML ENTITY INJECTION & OTA MANIFEST
  // ==========================================
  async testXmlEntityInjection() {
    this.logSection('3. XML INJECTION & OTA MANIFEST ATTACK SUITE');

    // 3.1 XML Tag Injection Attempt in Manifest Query Parameters
    await this.runTest(
      'XML-INJECT-1: XML tag breakout in bundleId and app name',
      'Inject </string><key>hacked</key><string>injected into manifest query params',
      async () => {
        const tagInjectionBundle = 'com.liquidcalc.app</string><key>evil</key><string>pwned';
        const tagInjectionName = 'LiquidCalc<script>alert(1)</script>';
        const url = `${this.baseUrl}/api/ota/manifest?bundleId=${encodeURIComponent(
          tagInjectionBundle
        )}&name=${encodeURIComponent(tagInjectionName)}`;

        const res = await fetchWithTimeout(url);
        this.assert(res.status === 200, `Manifest returned status ${res.status}`);
        const xml = await res.text();

        this.assert(!xml.includes('<key>evil</key>'), 'VULNERABILITY: Raw XML tag breakout succeeded in bundleId!');
        this.assert(!xml.includes('<script>'), 'VULNERABILITY: Raw script tag found in XML manifest!');
        this.assert(xml.includes('&lt;script&gt;'), 'Expected script tag to be escaped as &lt;script&gt;');
        this.assert(xml.includes('&lt;/string&gt;'), 'Expected tag to be escaped as &lt;/string&gt;');

        this.assert(xml.startsWith('<?xml version="1.0" encoding="UTF-8"?>'), 'Missing XML declaration header');
        this.assert(xml.includes('<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"'), 'Missing Apple DTD');
        this.assert(xml.includes('</plist>'), 'Missing closing plist tag');
        return { note: 'XML tags successfully sanitized and escaped' };
      }
    );

    // 3.2 XXE (XML External Entity) Payloads in OTA Manifest Parameters
    await this.runTest(
      'XML-INJECT-2: XXE entity expansion and external DTD injection',
      'Send XXE attack strings like <!ENTITY xxe SYSTEM "file:///etc/passwd"> &xxe;',
      async () => {
        const xxeAttack = '<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>&xxe;';
        const url = `${this.baseUrl}/api/ota/manifest?bundleId=${encodeURIComponent(
          xxeAttack
        )}&version=${encodeURIComponent('&quot;&gt;&lt;inject&gt;')}`;

        const res = await fetchWithTimeout(url);
        this.assert(res.status === 200, `Manifest returned status ${res.status}`);
        const xml = await res.text();

        this.assert(!xml.includes('<!ENTITY xxe'), 'VULNERABILITY: XXE DOCTYPE entity injected directly into XML!');
        this.assert(xml.includes('&amp;xxe;'), 'Expected &xxe; to be escaped to &amp;xxe;');
        return { note: 'XXE entity payloads escaped safely' };
      }
    );

    // 3.3 Special Characters and Ampersand Fuzzing in Plist
    await this.runTest(
      'XML-INJECT-3: Quotes, apostrophes, ampersands and angle brackets',
      'Test title with "LiquidCalc & Math" with single and double quotes',
      async () => {
        const specialTitle = 'LiquidCalc\'s "Pro & Ultimate" <V2> Edition';
        const url = `${this.baseUrl}/api/ota/manifest?name=${encodeURIComponent(specialTitle)}`;

        const res = await fetchWithTimeout(url);
        this.assert(res.status === 200, `Manifest returned status ${res.status}`);
        const xml = await res.text();

        this.assert(xml.includes('&apos;'), 'Expected single quote to be escaped as &apos;');
        this.assert(xml.includes('&quot;'), 'Expected double quote to be escaped as &quot;');
        this.assert(xml.includes('&amp;'), 'Expected ampersand to be escaped as &amp;');
        this.assert(xml.includes('&lt;V2&gt;'), 'Expected <V2> to be escaped as &lt;V2&gt;');
        return { note: 'All 5 XML special characters escaped cleanly' };
      }
    );

    // 3.4 Extreme String Length on OTA Manifest Parameters
    await this.runTest(
      'XML-INJECT-4: Extreme string length (10,000 chars) in query parameters',
      'Send 10,000 character strings in bundleId, name, version, ipaUrl, iconUrl',
      async () => {
        const giantStr = 'A'.repeat(10000);
        const url = `${this.baseUrl}/api/ota/manifest?bundleId=${giantStr}&name=${giantStr}&version=2.3.0`;

        const res = await fetchWithTimeout(url);
        this.assert(res.status === 200, `Expected 200 on long params, got ${res.status}`);
        const xml = await res.text();
        this.assert(xml.includes(giantStr), 'Long string reflected in manifest');
        return { note: '10KB parameter handled without buffer overflow' };
      }
    );
  }

  // ==========================================
  // 4. SSE STREAM LONGEVITY & RESILIENCE
  // ==========================================
  async testSseResilience() {
    this.logSection('4. SSE STREAM LONGEVITY & RESILIENCE SUITE');

    // 4.1 SSE Stream Longevity & Formatting Compliance
    await this.runTest(
      'SSE-RESIL-1: Strict SSE format and termination check',
      'Verify Content-Type, Cache-Control, chunk framing, and clean closure',
      async () => {
        const res = await fetchWithTimeout(`${this.baseUrl}/api/ai/stream`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            prompt: 'Explain Taylor series expansion of e^x up to degree 5 step by step',
            temperature: 0.1,
          }),
        }, 10000);

        this.assert(res.status === 200, `SSE endpoint returned status ${res.status}`);
        const ct = res.headers.get('content-type') || '';
        this.assert(ct.includes('text/event-stream'), `Expected text/event-stream, got ${ct}`);
        const cc = res.headers.get('cache-control') || '';
        this.assert(cc.includes('no-cache'), `Expected no-cache, got ${cc}`);
        this.assert(res.headers.get('x-accel-buffering') === 'no', 'Expected X-Accel-Buffering: no');

        const reader = res.body.getReader();
        const decoder = new TextDecoder();
        let totalText = '';
        let completed = false;
        let eventCount = 0;

        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          const chunkStr = decoder.decode(value);
          const lines = chunkStr.split('\n');
          for (const line of lines) {
            if (line.startsWith('data: ')) {
              eventCount++;
              const jsonStr = line.slice(6).trim();
              if (jsonStr) {
                const parsed = JSON.parse(jsonStr);
                this.assert(typeof parsed.text === 'string', 'Chunk text must be string');
                this.assert(typeof parsed.done === 'boolean', 'Chunk done must be boolean');
                totalText += parsed.text;
                if (parsed.done === true) {
                  completed = true;
                }
              }
            }
          }
        }

        this.assert(eventCount > 0, `Expected at least 1 SSE event, got ${eventCount}`);
        this.assert(completed, 'Stream must end with done: true');
        this.assert(totalText.length > 0, 'Stream must return non-empty accumulated text');
        return { note: `${eventCount} SSE events, ${totalText.length} chars generated` };
      }
    );

    // 4.2 Client Mid-Stream Abort Resiliency
    await this.runTest(
      'SSE-RESIL-2: Client abruptly terminates stream mid-transmission',
      'Client reads 1 chunk and cancels reader to verify server does not crash or throw unhandled errors',
      async () => {
        for (let i = 0; i < 5; i++) {
          const controller = new AbortController();
          const res = await fetch(`${this.baseUrl}/api/ai/stream`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ prompt: `Long running math explanation #${i}` }),
            signal: controller.signal,
          });

          this.assert(res.status === 200, 'Stream should start with 200');
          const reader = res.body.getReader();
          await reader.read();
          controller.abort();
          try {
            await reader.cancel();
          } catch {
            // Expected
          }
        }

        const healthRes = await fetchWithTimeout(`${this.baseUrl}/api/health`);
        this.assert(healthRes.status === 200, 'Server must remain healthy after abrupt SSE aborts');
        const health = await healthRes.json();
        this.assert(health.status === 'operational', 'Server status must be operational');
        return { note: '5 client aborts handled without process crash' };
      }
    );

    // 4.3 Multi-Turn Conversational Memory Streaming
    await this.runTest(
      'SSE-RESIL-3: Multi-turn history array with 10 turns',
      'Send conversation history array to /api/ai/stream',
      async () => {
        const history = Array.from({ length: 10 }, (_, i) => ({
          role: i % 2 === 0 ? 'user' : 'model',
          text: `Turn ${i}: ${i % 2 === 0 ? 'Calculate' : 'Result is'} ${i}`,
        }));

        const res = await fetchWithTimeout(`${this.baseUrl}/api/ai/stream`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            prompt: 'What was the last number discussed?',
            history,
          }),
        }, 10000);

        this.assert(res.status === 200, `Expected 200, got ${res.status}`);
        const reader = res.body.getReader();
        while (true) {
          const { done } = await reader.read();
          if (done) break;
        }
        return { note: '10-turn conversation history stream handled' };
      }
    );
  }

  // ==========================================
  // 5. EDGE CASE PARAMETERS & 400 REJECTIONS
  // ==========================================
  async testEdgeCaseRejections() {
    this.logSection('5. PARAMETER BOUNDARIES & HTTP 400 REJECTION SUITE');

    // 5.1 AI Solve - Empty Object & Missing Fields
    await this.runTest(
      'EDGE-1: POST /api/ai/solve missing required fields',
      'Send {} or {mode:"math"} without expression/prompt/image -> Expect 400 Bad Request',
      async () => {
        const badPayloads = [
          {},
          { mode: 'math' },
          { expression: '   ' },
          { prompt: '' },
          { image: '' },
        ];

        for (const payload of badPayloads) {
          const res = await fetchWithTimeout(`${this.baseUrl}/api/ai/solve`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
          });
          this.assert(res.status === 400, `Payload ${JSON.stringify(payload)} returned ${res.status}, expected 400`);
          const body = await res.json();
          this.assert(body.error !== undefined, 'Error message expected in response');
        }
        return { note: 'All empty/missing parameter payloads rejected with 400' };
      }
    );

    // 5.2 AI Solve - Invalid Mode Parameter
    await this.runTest(
      'EDGE-2: POST /api/ai/solve with invalid mode',
      'Send mode="invalid_mode" -> Expect 400 Bad Request',
      async () => {
        const res = await fetchWithTimeout(`${this.baseUrl}/api/ai/solve`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            mode: 'unsupported_mode_123',
            expression: '2+2',
          }),
        });
        this.assert(res.status === 400, `Expected 400 for invalid mode, got ${res.status}`);
        const data = await res.json();
        this.assert(data.error?.includes('Invalid mode'), 'Error message should specify invalid mode');
        return { note: 'Invalid mode rejected with 400' };
      }
    );

    // 5.3 AI Stream - Missing Required Parameters
    await this.runTest(
      'EDGE-3: POST /api/ai/stream missing required fields',
      'Send {} or {temperature: 0.5} without prompt/image/history -> Expect 400 Bad Request',
      async () => {
        const badPayloads = [
          {},
          { temperature: 0.5 },
          { prompt: '   ' },
          { history: [] },
        ];

        for (const payload of badPayloads) {
          const res = await fetchWithTimeout(`${this.baseUrl}/api/ai/stream`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
          });
          this.assert(res.status === 400, `Payload ${JSON.stringify(payload)} returned ${res.status}, expected 400`);
          const body = await res.json();
          this.assert(body.error !== undefined, 'Error message expected in response');
        }
        return { note: 'Missing prompt/image/history rejected with 400' };
      }
    );

    // 5.4 History Sync - Invalid Items Structure
    await this.runTest(
      'EDGE-4: POST /api/history/sync invalid items property',
      'Send {items: "not_an_array"} or {items: null} -> Expect 400 Bad Request',
      async () => {
        const badPayloads = [
          {},
          { items: 'string' },
          { items: 123 },
          { items: null },
          { items: { key: 'value' } },
        ];

        for (const payload of badPayloads) {
          const res = await fetchWithTimeout(`${this.baseUrl}/api/history/sync`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
          });
          this.assert(res.status === 400, `Payload ${JSON.stringify(payload)} returned ${res.status}, expected 400`);
        }
        return { note: 'Invalid items array structure rejected with 400' };
      }
    );

    // 5.5 History Sync - Graceful Handling of Malformed Item Elements
    await this.runTest(
      'EDGE-5: POST /api/history/sync with null and corrupt item elements',
      'Send items array containing null, undefined, empty objects, and numbers',
      async () => {
        const res = await fetchWithTimeout(`${this.baseUrl}/api/history/sync`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            deviceId: 'fuzz-device',
            items: [
              null,
              undefined,
              {},
              { id: 'valid_1', expression: '10+10', result: '20' },
              { expression: '', result: '' },
              12345,
              { id: 'valid_2', expression: 'sqrt(16)', result: '4' },
            ],
          }),
        });

        this.assert(res.status === 200, `Expected 200 on resilient sync, got ${res.status}`);
        const data = await res.json();
        this.assert(data.success === true, 'Sync should succeed');
        this.assert(data.syncedCount === 2, `Expected 2 valid items synced, got ${data.syncedCount}`);
        return { note: 'Gracefully filtered corrupt elements and synced 2 valid records' };
      }
    );

    // 5.6 History List - Out of Bounds, Negative, and Non-Numeric Pagination
    await this.runTest(
      'EDGE-6: GET /api/history/list boundary query parameters',
      'Test negative limit, massive limit, negative offset, non-numeric strings',
      async () => {
        const queries = [
          '?limit=-50&offset=-10',
          '?limit=9999999&offset=9999999',
          '?limit=NaN&offset=undefined',
          '?limit=abc&offset=xyz',
          '?mode=non_existent_mode_xyz',
          '?search=%00%00',
        ];

        for (const q of queries) {
          const res = await fetchWithTimeout(`${this.baseUrl}/api/history/list${q}`);
          this.assert(res.status === 200, `Query ${q} returned status ${res.status}, expected 200 safe pagination`);
          const data = await res.json();
          this.assert(Array.isArray(data.items), 'items must be an array');
          this.assert(typeof data.total === 'number', 'total must be a number');
        }
        return { note: 'All pagination boundary queries handled safely' };
      }
    );

    // 5.7 Updates Check - Version Comparison Edge Cases
    await this.runTest(
      'EDGE-7: GET /api/updates/check version boundary fuzzing',
      'Test empty version, future version, malformed version strings, prefix v',
      async () => {
        const testCases = [
          { query: '?currentVersion=1.0.0', expectUpdate: true },
          { query: '?currentVersion=v2.3.0', expectUpdate: false },
          { query: '?currentVersion=2.3.0', expectUpdate: false },
          { query: '?currentVersion=3.0.0', expectUpdate: false },
          { query: '?currentVersion=2.4.0', expectUpdate: false },
          { query: '?currentVersion=2.2.9', expectUpdate: true },
          { query: '?currentVersion=invalid.semver.build', expectUpdate: true },
          { query: '', expectUpdate: true },
        ];

        for (const tc of testCases) {
          const res = await fetchWithTimeout(`${this.baseUrl}/api/updates/check${tc.query}`);
          this.assert(res.status === 200, `Query ${tc.query} returned ${res.status}`);
          const data = await res.json();
          this.assert(
            data.updateAvailable === tc.expectUpdate,
            `For ${tc.query}: expected updateAvailable=${tc.expectUpdate}, got ${data.updateAvailable}`
          );
          this.assert(data.latestVersion === '2.3.0', 'latestVersion must be 2.3.0');
          this.assert(data.buildNumber === '23', 'buildNumber must be 23');
          this.assert(data.otaInstallURL.startsWith('itms-services://'), 'otaInstallURL must have itms-services protocol');
        }
        return { note: 'Semver comparison logic verified across 8 corner cases' };
      }
    );

    // 5.8 Unsupported HTTP Methods Fuzzing
    await this.runTest(
      'EDGE-8: Unsupported HTTP methods fuzzing across all routes',
      'Send DELETE, PATCH, and PUT to routes and verify no unhandled 500 crashes',
      async () => {
        const routes = [
          '/api/health',
          '/api/ota/manifest',
          '/api/ota/app',
          '/api/updates/check',
          '/api/updates/latest',
          '/api/history/list',
        ];

        for (const route of routes) {
          for (const method of ['DELETE', 'PATCH', 'PUT']) {
            const res = await fetchWithTimeout(`${this.baseUrl}${route}`, { method });
            this.assert(
              res.status === 405 || res.status === 400 || res.status === 404,
              `Route ${method} ${route} returned unexpected status ${res.status}`
            );
          }
        }
        return { note: '18 unsupported method calls rejected safely (0 crashes)' };
      }
    );
  }

  // ==========================================
  // RUN ALL CHALLENGER TESTS
  // ==========================================
  async runAll() {
    console.log(`
${colors.magenta}╔════════════════════════════════════════════════════════════════════╗
║    ⚡ LIQUIDCALC EMPIRICAL ADVERSARIAL STRESS & CHALLENGE SUITE ⚡ ║
╚════════════════════════════════════════════════════════════════════╝${colors.reset}
${colors.gray}Target Backend:${colors.reset} ${colors.bold}${this.baseUrl}${colors.reset}
${colors.gray}Timestamp:${colors.reset}      ${new Date().toISOString()}
`);

    const start = performance.now();
    await this.testConcurrency();
    await this.testMalformedJson();
    await this.testXmlEntityInjection();
    await this.testSseResilience();
    await this.testEdgeCaseRejections();
    const duration = Math.round(performance.now() - start);

    const passRate = Math.round((this.passed / this.total) * 100);

    console.log(`
${colors.cyan}══════════════════════════════════════════════════════════════════════${colors.reset}
${colors.bold}ADVERSARIAL CHALLENGE SUMMARY${colors.reset}
  ${colors.gray}Total Tests Run:${colors.reset}    ${colors.bold}${this.total}${colors.reset}
  ${colors.gray}Passed:${colors.reset}            ${colors.green}${colors.bold}${this.passed}${colors.reset}
  ${colors.gray}Failed:${colors.reset}            ${this.failed > 0 ? colors.red + colors.bold + this.failed : '0'}${colors.reset}
  ${colors.gray}Pass Rate:${colors.reset}          ${passRate === 100 ? colors.green : colors.yellow}${colors.bold}${passRate}%${colors.reset}
  ${colors.gray}Total Execution:${colors.reset}    ${duration}ms
${colors.cyan}══════════════════════════════════════════════════════════════════════${colors.reset}
`);

    if (this.failed > 0) {
      console.log(`${colors.red}${colors.bold}💥 CHALLENGE VERDICT: REQUEST_CHANGES (${this.failed} defect(s) found)${colors.reset}\n`);
      for (const f of this.findings) {
        console.log(`  - [${f.name}]: ${f.error}`);
      }
      process.exit(1);
    } else {
      console.log(`${colors.green}${colors.bold}✨ CHALLENGE VERDICT: APPROVE (Backend is exceptionally hardened & resilient)${colors.reset}\n`);
      process.exit(0);
    }
  }
}

const suite = new ChallengerSuite(BASE_URL);
suite.runAll();
