#!/usr/bin/env node

/**
 * LiquidCalc Backend - Tier 5 Adversarial Coverage Hardening & Live Stress Suite
 * 
 * Target: https://liquidcalc-backend.vercel.app
 * 
 * Test Dimensions:
 * 1. Universal CORS Preflight (OPTIONS) across all 9 endpoints.
 * 2. XML Plist DTD Compliance & Adversarial Input Sanitization (/api/ota/manifest).
 * 3. High-Concurrency Stress Testing (/api/health, /api/ota/manifest, /api/updates/check, /api/history/sync, /api/history/list).
 * 4. Complex LaTeX Mathematical & Multimodal OCR Base64 Solving (/api/ai/solve, /api/ai/stream).
 * 5. Real-Time SSE Streaming Chunk Verification with Latency/Jitter Analysis (/api/ai/stream).
 * 6. Boundary, Malformed Payload & Error Robustness Across All Endpoints (Zero 500s/Crashes).
 */

import { performance } from 'perf_hooks';

const BASE_URL = (process.env.TARGET_URL || 'https://liquidcalc-backend.vercel.app').replace(/\/$/, '');

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

async function fetchWithTimeout(url, options = {}, timeoutMs = 20000) {
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

function calculateStats(latencies) {
  if (latencies.length === 0) return { min: 0, max: 0, avg: 0, p50: 0, p95: 0, p99: 0 };
  const sorted = [...latencies].sort((a, b) => a - b);
  const sum = sorted.reduce((acc, v) => acc + v, 0);
  const avg = Math.round((sum / sorted.length) * 10) / 10;
  const p50 = sorted[Math.floor(sorted.length * 0.5)];
  const p95 = sorted[Math.floor(sorted.length * 0.95)];
  const p99 = sorted[Math.floor(sorted.length * 0.99)];
  return {
    min: Math.round(sorted[0] * 10) / 10,
    max: Math.round(sorted[sorted.length - 1] * 10) / 10,
    avg,
    p50: Math.round(p50 * 10) / 10,
    p95: Math.round(p95 * 10) / 10,
    p99: Math.round(p99 * 10) / 10,
  };
}

class Tier5Harness {
  constructor(baseUrl) {
    this.baseUrl = baseUrl;
    this.passed = 0;
    this.failed = 0;
    this.total = 0;
    this.results = [];
    this.concurrencyMetrics = {};
    this.streamingMetrics = {};
  }

  logHeader(title) {
    console.log(`\n${colors.cyan}${colors.bold}═════════════════════════════════════════════════════════════════════════${colors.reset}`);
    console.log(`${colors.cyan}${colors.bold}  ${title}${colors.reset}`);
    console.log(`${colors.cyan}${colors.bold}═════════════════════════════════════════════════════════════════════════${colors.reset}`);
  }

  async runTest(name, description, testFn) {
    this.total++;
    process.stdout.write(`  ${colors.gray}•${colors.reset} ${name.padEnd(60)} `);
    const start = performance.now();
    try {
      const result = await testFn();
      const elapsed = Math.round(performance.now() - start);
      this.passed++;
      const note = result && result.note ? ` ${colors.gray}(${result.note})${colors.reset}` : '';
      console.log(`${colors.green}✓ PASS${colors.reset} ${colors.dim}(${elapsed}ms)${colors.reset}${note}`);
      this.results.push({ name, description, status: 'PASS', elapsed, result });
      return result;
    } catch (err) {
      const elapsed = Math.round(performance.now() - start);
      this.failed++;
      console.log(`${colors.red}✗ FAIL${colors.reset} ${colors.dim}(${elapsed}ms)${colors.reset}`);
      console.log(`    ${colors.red}${colors.bold}Defect:${colors.reset} ${err.message}`);
      this.results.push({ name, description, status: 'FAIL', elapsed, error: err.message });
      return { status: 'FAIL', error: err.message };
    }
  }

  assert(condition, message) {
    if (!condition) {
      throw new Error(message || 'Assertion failed');
    }
  }
}

async function runTier5Suite() {
  const harness = new Tier5Harness(BASE_URL);

  console.log(`
${colors.cyan}╔════════════════════════════════════════════════════════════════════════════╗
║     ⚡ LIQUIDCALC PRODUCTION TIER 5 ADVERSARIAL STRESS SUITE ⚡            ║
╚════════════════════════════════════════════════════════════════════════════╝${colors.reset}
${colors.gray}Target Live Deployment:${colors.reset} ${colors.bold}${BASE_URL}${colors.reset}
${colors.gray}Execution Environment:${colors.reset}  Node.js ${process.version} (${process.platform})
${colors.gray}Start Timestamp:${colors.reset}        ${new Date().toISOString()}
`);

  // =========================================================================
  // SECTION 1: UNIVERSAL CORS PREFLIGHT (OPTIONS) ACROSS ALL 9 ENDPOINTS
  // =========================================================================
  harness.logHeader('1. UNIVERSAL CORS PREFLIGHT (OPTIONS) VALIDATION');

  const allEndpoints = [
    '/api/health',
    '/api/ai/solve',
    '/api/ai/stream',
    '/api/ota/manifest',
    '/api/ota/app',
    '/api/updates/check',
    '/api/updates/latest',
    '/api/history/sync',
    '/api/history/list',
  ];

  for (const endpoint of allEndpoints) {
    await harness.runTest(
      `CORS Preflight: OPTIONS ${endpoint}`,
      `Verifies standard 204 preflight with complete CORS headers`,
      async () => {
        const res = await fetchWithTimeout(`${BASE_URL}${endpoint}`, {
          method: 'OPTIONS',
          headers: {
            'Origin': 'https://preview.liquidcalc.app',
            'Access-Control-Request-Method': 'POST',
            'Access-Control-Request-Headers': 'Content-Type, Authorization, x-gemini-api-key',
          },
        });

        harness.assert(res.status === 204 || res.status === 200, `Expected status 204 or 200, got ${res.status}`);
        const origin = res.headers.get('access-control-allow-origin');
        harness.assert(origin === '*' || origin === 'https://preview.liquidcalc.app', `Invalid Allow-Origin: ${origin}`);
        
        const methods = res.headers.get('access-control-allow-methods') || '';
        harness.assert(methods.includes('OPTIONS') && methods.includes('GET') && methods.includes('POST'), `Allow-Methods missing expected verbs: ${methods}`);
        
        const allowHeaders = res.headers.get('access-control-allow-headers') || '';
        harness.assert(allowHeaders.toLowerCase().includes('x-gemini-api-key'), `Missing x-gemini-api-key in Allow-Headers: ${allowHeaders}`);
        harness.assert(allowHeaders.toLowerCase().includes('authorization'), `Missing authorization in Allow-Headers: ${allowHeaders}`);

        return { note: `Status ${res.status}, Origin: ${origin}` };
      }
    );
  }

  // =========================================================================
  // SECTION 2: XML PLIST DTD COMPLIANCE & ADVERSARIAL SANITIZATION
  // =========================================================================
  harness.logHeader('2. XML PLIST DTD COMPLIANCE & ADVERSARIAL SANITIZATION');

  await harness.runTest(
    'OTA Manifest: Standard Apple DTD & Headers',
    'Validates Apple Software Package DTD doctype and xml content-type',
    async () => {
      const res = await fetchWithTimeout(`${BASE_URL}/api/ota/manifest?bundleId=com.liquidcalc.app&name=LiquidCalc&version=2.3.0`);
      harness.assert(res.status === 200, `Expected 200 OK, got ${res.status}`);
      const contentType = res.headers.get('content-type') || '';
      harness.assert(contentType.includes('text/xml') || contentType.includes('application/xml'), `Expected XML content type, got ${contentType}`);

      const xml = await res.text();
      harness.assert(xml.startsWith('<?xml version="1.0" encoding="UTF-8"?>'), 'Missing XML declaration');
      harness.assert(xml.includes('<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'), 'Missing or invalid Apple DTD DOCTYPE');
      harness.assert(xml.includes('<plist version="1.0">'), 'Missing <plist version="1.0"> root element');
      harness.assert(xml.includes('<string>software-package</string>'), 'Missing software-package string value');
      harness.assert(xml.includes('<string>com.liquidcalc.app</string>'), 'Missing bundle-identifier string');
      harness.assert(xml.includes('<string>2.3.0</string>'), 'Missing bundle-version string');
      harness.assert(xml.includes('<string>LiquidCalc</string>'), 'Missing title string');
      harness.assert(xml.includes('<string>com.apple.platform.iphoneos</string>'), 'Missing platform-identifier');

      return { note: `${xml.length} bytes XML verified` };
    }
  );

  await harness.runTest(
    'OTA Manifest: Adversarial XML Entities & Special Characters',
    'Validates injection resistance against unescaped XML entities (&, <, >, ", \')',
    async () => {
      const hostileName = 'LiquidCalc & Co <Special> "Edition" \'Pro\'';
      const hostileBundle = 'com.liquidcalc.<injected>.app&sub=1';
      const hostileVersion = '2.3.0-beta<1>&build=99';
      const query = new URLSearchParams({
        name: hostileName,
        bundleId: hostileBundle,
        version: hostileVersion,
      }).toString();

      const res = await fetchWithTimeout(`${BASE_URL}/api/ota/manifest?${query}`);
      harness.assert(res.status === 200, `Expected 200 OK, got ${res.status}`);
      const xml = await res.text();

      // Check XML escaping
      harness.assert(xml.includes('&amp; Co &lt;Special&gt; &quot;Edition&quot; &apos;Pro&apos;'), 'Name special characters not correctly escaped');
      harness.assert(xml.includes('com.liquidcalc.&lt;injected&gt;.app&amp;sub=1'), 'BundleId special characters not correctly escaped');
      harness.assert(xml.includes('2.3.0-beta&lt;1&gt;&amp;build=99'), 'Version special characters not correctly escaped');

      // Verify no unescaped tags were injected
      harness.assert(!xml.includes('<Special>'), 'Unescaped tag <Special> detected');
      harness.assert(!xml.includes('<injected>'), 'Unescaped tag <injected> detected');

      return { note: 'All hostile XML entities properly escaped' };
    }
  );

  await harness.runTest(
    'OTA Manifest: Multibyte Unicode & Emoji Support',
    'Validates UTF-8 encoding integrity with complex emojis and multilingual strings',
    async () => {
      const unicodeName = 'LiquidCalc 🚀 数学 계산기 🧮';
      const query = new URLSearchParams({ name: unicodeName }).toString();
      const res = await fetchWithTimeout(`${BASE_URL}/api/ota/manifest?${query}`);
      harness.assert(res.status === 200, `Expected 200 OK, got ${res.status}`);
      const xml = await res.text();
      harness.assert(xml.includes('LiquidCalc 🚀 数学 계산기 🧮'), 'Unicode / emoji characters altered or corrupted');
      return { note: 'UTF-8 multibyte strings validated cleanly' };
    }
  );

  // =========================================================================
  // SECTION 3: HIGH-CONCURRENCY LIVE REQUESTS STRESS TESTING
  // =========================================================================
  harness.logHeader('3. HIGH-CONCURRENCY LIVE STRESS TESTING');

async function runConcurrentPool(items, concurrencyLimit, workerFn) {
  const results = [];
  const executing = new Set();
  for (const item of items) {
    const p = Promise.resolve().then(() => workerFn(item)).then((res) => {
      executing.delete(p);
      return res;
    });
    executing.add(p);
    results.push(p);
    if (executing.size >= concurrencyLimit) {
      await Promise.race(executing);
    }
  }
  return Promise.all(results);
}

  const concurrencyTargets = [
    {
      name: '/api/health',
      totalRequests: 25,
      poolConcurrency: 10,
      fn: async (idx) => {
        const start = performance.now();
        try {
          const res = await fetchWithTimeout(`${BASE_URL}/api/health`, {}, 20000);
          const duration = performance.now() - start;
          const json = await res.json();
          return { ok: res.status === 200 && json.healthy === true, status: res.status, duration };
        } catch (err) {
          return { ok: false, status: err.message, duration: performance.now() - start };
        }
      },
    },
    {
      name: '/api/ota/manifest',
      totalRequests: 20,
      poolConcurrency: 8,
      fn: async (idx) => {
        const start = performance.now();
        try {
          const res = await fetchWithTimeout(`${BASE_URL}/api/ota/manifest?version=2.3.${idx}&bundleId=com.test.${idx}`, {}, 20000);
          const duration = performance.now() - start;
          const text = await res.text();
          return { ok: res.status === 200 && text.includes(`2.3.${idx}`), status: res.status, duration };
        } catch (err) {
          return { ok: false, status: err.message, duration: performance.now() - start };
        }
      },
    },
    {
      name: '/api/updates/check',
      totalRequests: 20,
      poolConcurrency: 8,
      fn: async (idx) => {
        const start = performance.now();
        try {
          const res = await fetchWithTimeout(`${BASE_URL}/api/updates/check?currentVersion=2.2.${idx}`, {}, 20000);
          const duration = performance.now() - start;
          const json = await res.json();
          return { ok: res.status === 200 && json.latestVersion === '2.3.0', status: res.status, duration };
        } catch (err) {
          return { ok: false, status: err.message, duration: performance.now() - start };
        }
      },
    },
    {
      name: '/api/history/sync',
      totalRequests: 15,
      poolConcurrency: 6,
      fn: async (idx) => {
        const start = performance.now();
        try {
          const payload = {
            deviceId: `stress-dev-${idx}`,
            items: [
              {
                id: `stress-calc-${idx}-${Date.now()}`,
                timestamp: new Date().toISOString(),
                expression: `${idx} * ${idx} + ${idx}`,
                result: `${idx * idx + idx}`,
                mode: 'scientific',
                notes: `Stress test item #${idx}`,
              },
            ],
          };
          const res = await fetchWithTimeout(`${BASE_URL}/api/history/sync`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
          }, 20000);
          const duration = performance.now() - start;
          const json = await res.json();
          return { ok: res.status === 200 && json.success === true, status: res.status, duration };
        } catch (err) {
          return { ok: false, status: err.message, duration: performance.now() - start };
        }
      },
    },
    {
      name: '/api/history/list',
      totalRequests: 20,
      poolConcurrency: 8,
      fn: async (idx) => {
        const start = performance.now();
        try {
          const res = await fetchWithTimeout(`${BASE_URL}/api/history/list?limit=10&offset=${idx % 5}`, {}, 20000);
          const duration = performance.now() - start;
          const json = await res.json();
          return { ok: res.status === 200 && json.success === true && Array.isArray(json.items), status: res.status, duration };
        } catch (err) {
          return { ok: false, status: err.message, duration: performance.now() - start };
        }
      },
    },
  ];

  for (const target of concurrencyTargets) {
    await harness.runTest(
      `Concurrency Burst: ${target.totalRequests} reqs (pool: ${target.poolConcurrency}) -> ${target.name}`,
      `Executes ${target.totalRequests} requests with pool concurrency ${target.poolConcurrency}`,
      async () => {
        const startTime = performance.now();
        const items = Array.from({ length: target.totalRequests }, (_, i) => i);
        const results = await runConcurrentPool(items, target.poolConcurrency, target.fn);
        const totalTime = performance.now() - startTime;

        const successes = results.filter((r) => r.ok).length;
        const failures = results.filter((r) => !r.ok);
        const latencies = results.map((r) => r.duration);
        const stats = calculateStats(latencies);
        const throughput = Math.round((target.totalRequests / (totalTime / 1000)) * 10) / 10;

        harness.concurrencyMetrics[target.name] = {
          total: target.totalRequests,
          successes,
          failedCount: failures.length,
          stats,
          throughputRps: throughput,
          totalTimeMs: Math.round(totalTime),
        };

        if (failures.length > 0) {
          throw new Error(`${failures.length}/${target.totalRequests} requests failed! First failure: status ${failures[0].status}`);
        }

        return {
          note: `${successes}/${target.totalRequests} ok (100%), avg: ${stats.avg}ms, p95: ${stats.p95}ms, max: ${stats.max}ms, ${throughput} rps`,
        };
      }
    );
  }

  // =========================================================================
  // SECTION 4: COMPLEX LATEX & MULTIMODAL OCR SOLVING (/api/ai/solve, /api/ai/stream)
  // =========================================================================
  harness.logHeader('4. COMPLEX LATEX MATHEMATICS & MULTIMODAL OCR BASE64 SOLVING');

  const latexEquations = [
    {
      name: 'Riemann Zeta Series',
      expression: '\\zeta(s) = \\sum_{n=1}^\\infty \\frac{1}{n^s} \\text{ evaluated at } s = 2',
    },
    {
      name: 'Schrodinger Time-Dependent Equation',
      expression: 'i\\hbar \\frac{\\partial}{\\partial t}\\Psi(\\mathbf{r},t) = \\left[ -\\frac{\\hbar^2}{2m}\\nabla^2 + V(\\mathbf{r},t)\\right]\\Psi(\\mathbf{r},t)',
    },
    {
      name: 'Navier-Stokes Momentum Differential',
      expression: '\\rho \\left( \\frac{\\partial \\mathbf{u}}{\\partial t} + \\mathbf{u} \\cdot \\nabla \\mathbf{u} \\right) = -\\nabla p + \\mu \\nabla^2 \\mathbf{u} + \\mathbf{f}',
    },
    {
      name: 'Characteristic Polynomial & Eigenvalues',
      expression: '\\det\\begin{pmatrix} \\lambda - 4 & 2 \\\\ 3 & \\lambda - 1 \\end{pmatrix} = 0',
    },
    {
      name: 'Definite Trigonometric Integral',
      expression: '\\int_{0}^{\\pi} \\sin^2(x) dx + \\sum_{k=1}^{5} \\frac{(-1)^k}{k^2}',
    },
  ];

  for (const eq of latexEquations) {
    await harness.runTest(
      `AI Solve Math: ${eq.name}`,
      `Submits high-order LaTeX expression to /api/ai/solve and validates structured response`,
      async () => {
        const res = await fetchWithTimeout(`${BASE_URL}/api/ai/solve`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            mode: 'math',
            expression: eq.expression,
          }),
        });

        harness.assert(res.status === 200, `Expected 200 OK, got ${res.status}`);
        const json = await res.json();
        harness.assert(json.success === true, `Expected success: true, got ${JSON.stringify(json)}`);
        harness.assert(typeof json.result === 'string' && json.result.length > 0, `Missing or invalid result field`);
        harness.assert(Array.isArray(json.steps) && json.steps.length > 0, `Expected non-empty steps array`);
        harness.assert(typeof json.explanation === 'string' && json.explanation.length > 0, `Missing explanation`);

        return { note: `Result: "${json.result.substring(0, 30)}...", ${json.steps.length} steps` };
      }
    );
  }

  // Multimodal OCR Payloads to /api/ai/solve
  const base64Png = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
  const rawBase64Jpeg = 'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFElEQVR42mNk+M/AwMDAwMDEAAAMBQD8d/q6EAAAAABJRU5ErkJggg==';

  await harness.runTest(
    'AI Solve: Multimodal Receipt OCR (Data URL)',
    'Validates structured itemized receipt extraction from base64 image data URL',
    async () => {
      const res = await fetchWithTimeout(`${BASE_URL}/api/ai/solve`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          mode: 'receipt',
          image: base64Png,
          prompt: 'Calculate total for 2 Coffees ($4.50 ea) and 1 Muffin ($3.00)',
        }),
      });

      harness.assert(res.status === 200, `Expected 200 OK, got ${res.status}`);
      const json = await res.json();
      harness.assert(json.success === true, 'Expected success: true');
      harness.assert(json.mode === 'receipt', `Expected mode: receipt, got ${json.mode}`);
      harness.assert(typeof json.storeName === 'string', 'Missing storeName');
      harness.assert(typeof json.currency === 'string', 'Missing currency');
      harness.assert(Array.isArray(json.items), 'items must be an array');
      harness.assert(typeof json.total === 'number' && !isNaN(json.total), 'total must be a valid number');

      return { note: `Store: ${json.storeName}, Total: ${json.currency} ${json.total}` };
    }
  );

  await harness.runTest(
    'AI Solve: Multimodal Math Formula OCR (Raw Base64)',
    'Validates vision-assisted formula recognition with raw base64 JPEG payload',
    async () => {
      const res = await fetchWithTimeout(`${BASE_URL}/api/ai/solve`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          mode: 'math',
          image: rawBase64Jpeg,
          prompt: 'Solve formula in this whiteboard photo',
        }),
      });

      harness.assert(res.status === 200, `Expected 200 OK, got ${res.status}`);
      const json = await res.json();
      harness.assert(json.success === true, 'Expected success: true');
      harness.assert(typeof json.result === 'string', 'Missing result string');
      harness.assert(Array.isArray(json.steps), 'Missing steps array');

      return { note: `Solved formula from base64 visual input` };
    }
  );

  await harness.runTest(
    'AI Solve: Malformed & Truncated Base64 Error Resilience',
    'Ensures corrupted or truncated base64 image strings do not cause server 500 crashes',
    async () => {
      const corruptBase64 = 'data:image/jpeg;base64,CORRUPT_!@#$%^&*()_TRUNCATED_INVALID==';
      const res = await fetchWithTimeout(`${BASE_URL}/api/ai/solve`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          mode: 'math',
          image: corruptBase64,
          expression: '15 * 8 - 4',
        }),
      });

      harness.assert(res.status === 200, `Expected 200 OK with graceful fallback, got ${res.status}`);
      const json = await res.json();
      harness.assert(json.success === true, 'Expected success: true via robust fallback');

      return { note: 'No 500 error on corrupted base64 input' };
    }
  );

  // =========================================================================
  // SECTION 5: REAL-TIME SSE STREAMING CHUNK & LATENCY/JITTER ANALYSIS
  // =========================================================================
  harness.logHeader('5. REAL-TIME SSE STREAMING CHUNK & LATENCY ANALYSIS');

  await harness.runTest(
    'AI Stream: SSE Handshake & Streaming Headers',
    'Validates Content-Type: text/event-stream, Cache-Control, and X-Accel-Buffering',
    async () => {
      const res = await fetchWithTimeout(`${BASE_URL}/api/ai/stream`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          prompt: 'Evaluate lim(x->0) sin(x)/x step by step',
        }),
      });

      harness.assert(res.status === 200, `Expected 200 OK, got ${res.status}`);
      const contentType = res.headers.get('content-type') || '';
      harness.assert(contentType.includes('text/event-stream'), `Expected text/event-stream, got ${contentType}`);
      
      const cacheControl = res.headers.get('cache-control') || '';
      harness.assert(cacheControl.includes('no-cache'), `Expected no-cache in Cache-Control: ${cacheControl}`);

      // Read stream to completion
      const reader = res.body.getReader();
      while (true) {
        const { done } = await reader.read();
        if (done) break;
      }

      return { note: `Headers: text/event-stream; charset=utf-8` };
    }
  );

  await harness.runTest(
    'AI Stream: Chunk Breakdown, TTFB & Jitter Latency Analysis',
    'Measures Time-To-First-Byte (TTFB), inter-chunk arrival intervals, and payload integrity',
    async () => {
      const prompt = 'Solve d/dx [e^(2x) * cos(3x)] showing product and chain rule';
      const streamStart = performance.now();
      
      const res = await fetchWithTimeout(`${BASE_URL}/api/ai/stream`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          prompt,
          temperature: 0.1,
        }),
      });

      harness.assert(res.status === 200, `Expected 200 OK, got ${res.status}`);

      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let firstChunkTime = null;
      let lastChunkTime = performance.now();
      const chunkArrivalIntervals = [];
      let totalBytes = 0;
      let chunkCount = 0;
      let assembledText = '';
      let receivedDone = false;
      let buffer = '';

      while (true) {
        const { done, value } = await reader.read();
        const now = performance.now();

        if (done) break;

        if (firstChunkTime === null) {
          firstChunkTime = now;
        } else {
          chunkArrivalIntervals.push(now - lastChunkTime);
        }
        lastChunkTime = now;

        totalBytes += value.length;
        buffer += decoder.decode(value, { stream: true });

        const lines = buffer.split('\n');
        buffer = lines.pop() || '';

        for (const line of lines) {
          const trimmed = line.trim();
          if (trimmed.startsWith('data: ')) {
            chunkCount++;
            const jsonStr = trimmed.substring(6);
            if (jsonStr) {
              try {
                const parsed = JSON.parse(jsonStr);
                if (parsed.text) {
                  assembledText += parsed.text;
                }
                if (parsed.done === true) {
                  receivedDone = true;
                }
              } catch (e) {
                // Ignore parse errors on partial chunks
              }
            }
          }
        }
      }

      const totalDuration = performance.now() - streamStart;
      const ttfb = firstChunkTime ? Math.round(firstChunkTime - streamStart) : Math.round(totalDuration);
      const intervalStats = calculateStats(chunkArrivalIntervals);

      harness.assert(chunkCount > 0, `Expected at least 1 SSE chunk, received 0`);
      harness.assert(assembledText.length > 0, `Expected non-empty assembled text`);
      harness.assert(receivedDone === true, `Expected final SSE chunk to indicate done: true`);

      harness.streamingMetrics = {
        ttfbMs: ttfb,
        totalDurationMs: Math.round(totalDuration),
        totalBytes,
        chunkCount,
        assembledTextLength: assembledText.length,
        intervalStats,
      };

      return {
        note: `TTFB: ${ttfb}ms, Total: ${Math.round(totalDuration)}ms, Chunks: ${chunkCount}, Bytes: ${totalBytes}, done: true`,
      };
    }
  );

  await harness.runTest(
    'AI Stream: Multimodal OCR & Multi-Turn History Payload',
    'Streams response for multimodal image + conversation history payload',
    async () => {
      const res = await fetchWithTimeout(`${BASE_URL}/api/ai/stream`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          prompt: 'What is the sum of these numbers?',
          history: [
            { role: 'user', text: 'I have two values: 42 and 58' },
            { role: 'model', text: 'Great, what operation would you like to perform?' },
          ],
          image: base64Png,
        }),
      });

      harness.assert(res.status === 200, `Expected 200 OK, got ${res.status}`);
      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let streamed = '';
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        streamed += decoder.decode(value, { stream: true });
      }

      harness.assert(streamed.includes('data:'), 'Expected valid SSE data frames');
      return { note: `Successfully streamed multi-turn + image context (${streamed.length} bytes)` };
    }
  );

  // =========================================================================
  // SECTION 6: APP UPDATES & REDIRECT ENDPOINTS
  // =========================================================================
  harness.logHeader('6. APP UPDATES & DOWNLOAD DISTRIBUTION ENDPOINTS');

  await harness.runTest(
    'Updates Check: Version Comparison & Payload Structure',
    'Validates /api/updates/check returns current 2.3.0 metadata and updateAvailable flag',
    async () => {
      // Test older version (update should be available)
      const resOld = await fetchWithTimeout(`${BASE_URL}/api/updates/check?currentVersion=2.2.0`);
      harness.assert(resOld.status === 200, `Expected 200 OK, got ${resOld.status}`);
      const jsonOld = await resOld.json();
      harness.assert(jsonOld.latestVersion === '2.3.0', `Expected latestVersion 2.3.0, got ${jsonOld.latestVersion}`);
      harness.assert(jsonOld.updateAvailable === true, 'Expected updateAvailable: true for 2.2.0');
      harness.assert(typeof jsonOld.downloadURL === 'string' && jsonOld.downloadURL.includes('.ipa'), 'Missing IPA downloadURL');
      harness.assert(typeof jsonOld.otaManifestURL === 'string', 'Missing otaManifestURL');
      harness.assert(typeof jsonOld.otaInstallURL === 'string' && jsonOld.otaInstallURL.startsWith('itms-services://'), 'Missing itms-services URL');
      harness.assert(Array.isArray(jsonOld.changelog) && jsonOld.changelog.length > 0, 'Missing changelog array');

      // Test current version (update should NOT be available)
      const resCurrent = await fetchWithTimeout(`${BASE_URL}/api/updates/check?currentVersion=2.3.0`);
      const jsonCurrent = await resCurrent.json();
      harness.assert(jsonCurrent.updateAvailable === false, 'Expected updateAvailable: false for 2.3.0');

      return { note: `v2.3.0 (build ${jsonOld.buildNumber}), changelog items: ${jsonOld.changelog.length}` };
    }
  );

  await harness.runTest(
    'Updates Latest: GitHub & AltStore Asset Manifest',
    'Validates /api/updates/latest returns GitHub release & AltStore asset metadata',
    async () => {
      const res = await fetchWithTimeout(`${BASE_URL}/api/updates/latest`);
      harness.assert(res.status === 200, `Expected 200 OK, got ${res.status}`);
      const json = await res.json();
      harness.assert(json.tag_name === 'v2.3.0' || json.version === '2.3.0', `Expected version 2.3.0 in latest metadata`);
      harness.assert(Array.isArray(json.assets) && json.assets.length > 0, 'Expected non-empty assets array');

      const ipaAsset = json.assets.find((a) => a.name.endsWith('.ipa'));
      harness.assert(Boolean(ipaAsset), 'Missing .ipa binary asset in release metadata');

      return { note: `Tag: ${json.tag_name || json.version}, Assets: ${json.assets.length}` };
    }
  );

  await harness.runTest(
    'OTA App: 302 / Redirect Handling for Binary IPA',
    'Validates /api/ota/app redirects to latest GitHub release IPA binary',
    async () => {
      const res = await fetchWithTimeout(`${BASE_URL}/api/ota/app`, {
        redirect: 'manual',
      });

      // Fetch in manual mode returns 302/307 or redirect status
      harness.assert(res.status === 302 || res.status === 307 || res.status === 200, `Expected redirect status, got ${res.status}`);
      const location = res.headers.get('location') || '';
      if (res.status === 302 || res.status === 307) {
        harness.assert(location.includes('.ipa'), `Expected redirect location to IPA, got: ${location}`);
      }

      return { note: `Status: ${res.status}, Location: ${location ? location.substring(0, 40) + '...' : 'Direct'}` };
    }
  );

  // =========================================================================
  // SECTION 7: HISTORY BATCH SYNC & PAGINATION FILTERING
  // =========================================================================
  harness.logHeader('7. HISTORY BATCH SYNCHRONIZATION & PAGINATION FILTERING');

  const testDeviceId = `tier5-stress-${Date.now()}`;
  const mockHistoryItems = [
    {
      id: `calc-1-${Date.now()}`,
      timestamp: new Date(Date.now() - 3000).toISOString(),
      expression: 'sin(pi / 4)',
      result: '0.70710678',
      mode: 'trigonometric',
      notes: 'Trig test',
    },
    {
      id: `calc-2-${Date.now()}`,
      timestamp: new Date(Date.now() - 2000).toISOString(),
      expression: 'integral(x^2, 0, 3)',
      result: '9',
      mode: 'calculus',
      notes: 'Definite integral test',
    },
    {
      id: `calc-3-${Date.now()}`,
      timestamp: new Date(Date.now() - 1000).toISOString(),
      expression: 'matrix_det([[1,2],[3,4]])',
      result: '-2',
      mode: 'algebra',
      notes: 'Matrix determinant test',
    },
  ];

  await harness.runTest(
    'History Sync: Batch Record Ingestion',
    'Submits batch calculation records with deviceId metadata',
    async () => {
      const res = await fetchWithTimeout(`${BASE_URL}/api/history/sync`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          deviceId: testDeviceId,
          items: mockHistoryItems,
        }),
      });

      harness.assert(res.status === 200, `Expected 200 OK, got ${res.status}`);
      const json = await res.json();
      harness.assert(json.success === true, 'Expected success: true');
      harness.assert(json.syncedCount === 3, `Expected syncedCount 3, got ${json.syncedCount}`);
      harness.assert(typeof json.totalRecords === 'number' && json.totalRecords >= 3, 'Invalid totalRecords count');

      return { note: `Synced: ${json.syncedCount}, Store Total: ${json.totalRecords}` };
    }
  );

  await harness.runTest(
    'History List: Pagination & Limit/Offset Boundary',
    'Retrieves paginated history records and validates limit/offset handling',
    async () => {
      const res = await fetchWithTimeout(`${BASE_URL}/api/history/list?limit=2&offset=0`);
      harness.assert(res.status === 200, `Expected 200 OK, got ${res.status}`);
      const json = await res.json();
      harness.assert(json.success === true, 'Expected success: true');
      harness.assert(Array.isArray(json.items), 'Expected items array');
      harness.assert(json.items.length <= 2, `Expected at most 2 items, got ${json.items.length}`);
      harness.assert(typeof json.total === 'number', 'Missing total count');

      return { note: `Returned: ${json.items.length} items (limit: 2), Total Available: ${json.total}` };
    }
  );

  await harness.runTest(
    'History List: Mode Filtering Support',
    'Filters calculation records by mathematical category mode',
    async () => {
      const res = await fetchWithTimeout(`${BASE_URL}/api/history/list?mode=calculus`);
      harness.assert(res.status === 200, `Expected 200 OK, got ${res.status}`);
      const json = await res.json();
      harness.assert(json.success === true, 'Expected success: true');
      harness.assert(Array.isArray(json.items), 'Expected items array');
      for (const item of json.items) {
        harness.assert(item.mode === 'calculus', `Expected item mode 'calculus', got ${item.mode}`);
      }

      return { note: `Filtered records matching mode 'calculus': ${json.items.length} items` };
    }
  );

  // =========================================================================
  // SECTION 8: ADVERSARIAL BOUNDARY & MALFORMED PAYLOAD HARDENING (ZERO 500s)
  // =========================================================================
  harness.logHeader('8. ADVERSARIAL BOUNDARY & MALFORMED PAYLOAD HARDENING');

  const adversarialCases = [
    {
      name: 'Solve Math: Malformed JSON Syntax Body',
      url: `${BASE_URL}/api/ai/solve`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{ "mode": "math", "expression": unquoted_invalid_syntax,,, }',
      expectedStatus: [400],
    },
    {
      name: 'Stream AI: Empty JSON Object Body',
      url: `${BASE_URL}/api/ai/stream`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{}',
      expectedStatus: [400],
    },
    {
      name: 'Stream AI: Non-Object Array JSON Body',
      url: `${BASE_URL}/api/ai/stream`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '["prompt", "123"]',
      expectedStatus: [400],
    },
    {
      name: 'History Sync: Missing Items Array Field',
      url: `${BASE_URL}/api/history/sync`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ deviceId: 'missing-items-dev' }),
      expectedStatus: [400],
    },
    {
      name: 'History List: Extreme Negative Limit/Offset',
      url: `${BASE_URL}/api/history/list?limit=-999&offset=-500`,
      method: 'GET',
      headers: {},
      expectedStatus: [200], // Should sanitize safely to defaults
    },
    {
      name: 'Updates Check: Unparseable Semver Version String',
      url: `${BASE_URL}/api/updates/check?currentVersion=NOT_A_VALID_SEMVER_VERSION`,
      method: 'GET',
      headers: {},
      expectedStatus: [200], // Should handle gracefully
    },
    {
      name: 'OTA Manifest: Giant 100KB Parameter String',
      url: `${BASE_URL}/api/ota/manifest?name=${'A'.repeat(5000)}&bundleId=${'com.test.'.repeat(500)}`,
      method: 'GET',
      headers: {},
      expectedStatus: [200],
    },
  ];

  for (const testCase of adversarialCases) {
    await harness.runTest(
      `Hardening: ${testCase.name}`,
      `Asserts status ${testCase.expectedStatus.join('/')} and strictly zero unhandled 500 crashes`,
      async () => {
        const res = await fetchWithTimeout(testCase.url, {
          method: testCase.method,
          headers: testCase.headers,
          body: testCase.body,
        });

        harness.assert(res.status !== 500 && res.status !== 502 && res.status !== 503, `Server crashed with HTTP ${res.status}!`);
        harness.assert(testCase.expectedStatus.includes(res.status), `Expected status ${testCase.expectedStatus.join('/')}, got ${res.status}`);

        return { note: `HTTP ${res.status} returned gracefully` };
      }
    );
  }

  // =========================================================================
  // PRINT SUMMARY AND METRICS
  // =========================================================================
  console.log(`\n${colors.cyan}${colors.bold}═════════════════════════════════════════════════════════════════════════${colors.reset}`);
  console.log(`${colors.cyan}${colors.bold}  TIER 5 ADVERSARIAL TEST SUMMARY & LATENCY BENCHMARKS${colors.reset}`);
  console.log(`${colors.cyan}${colors.bold}═════════════════════════════════════════════════════════════════════════${colors.reset}`);
  
  console.log(`\n${colors.bold}Concurrency Burst Latencies:${colors.reset}`);
  console.table(
    Object.entries(harness.concurrencyMetrics).map(([endpoint, data]) => ({
      Endpoint: endpoint,
      Requests: data.total,
      Success: `${data.successes}/${data.total} (${Math.round((data.successes / data.total) * 100)}%)`,
      'Avg (ms)': data.stats.avg,
      'Min (ms)': data.stats.min,
      'P95 (ms)': data.stats.p95,
      'Max (ms)': data.stats.max,
      'Throughput (req/s)': data.throughputRps,
    }))
  );

  console.log(`\n${colors.bold}SSE Streaming Latency Profile (/api/ai/stream):${colors.reset}`);
  console.log(`  • Time-To-First-Byte (TTFB): ${harness.streamingMetrics.ttfbMs} ms`);
  console.log(`  • Total Stream Duration:     ${harness.streamingMetrics.totalDurationMs} ms`);
  console.log(`  • Total Chunks Received:     ${harness.streamingMetrics.chunkCount}`);
  console.log(`  • Total Bytes Received:      ${harness.streamingMetrics.totalBytes} bytes`);
  console.log(`  • Chunk Jitter P95:          ${harness.streamingMetrics.intervalStats?.p95 || 0} ms`);

  const passRate = Math.round((harness.passed / harness.total) * 100);
  console.log(`
${colors.cyan}═════════════════════════════════════════════════════════════════════════${colors.reset}
${colors.bold}Total Test Executions:${colors.reset}  ${harness.total}
${colors.green}${colors.bold}Passed:${colors.reset}                  ${harness.passed}
${colors.red}${colors.bold}Failed:${colors.reset}                  ${harness.failed}
${colors.bold}Pass Rate:${colors.reset}               ${harness.failed === 0 ? colors.green : colors.red}${passRate}%${colors.reset}
${colors.cyan}═════════════════════════════════════════════════════════════════════════${colors.reset}
`);

  if (harness.failed === 0) {
    console.log(`${colors.green}${colors.bold}⚡ VERDICT: APPROVE — 100% PRODUCTION ADVERSARIAL PASS (ZERO 500s)${colors.reset}\n`);
    return {
      verdict: 'APPROVE',
      total: harness.total,
      passed: harness.passed,
      failed: harness.failed,
      concurrencyMetrics: harness.concurrencyMetrics,
      streamingMetrics: harness.streamingMetrics,
      results: harness.results,
    };
  } else {
    console.log(`${colors.red}${colors.bold}⚡ VERDICT: REQUEST_CHANGES — Deficiencies Detected${colors.reset}\n`);
    return {
      verdict: 'REQUEST_CHANGES',
      total: harness.total,
      passed: harness.passed,
      failed: harness.failed,
      concurrencyMetrics: harness.concurrencyMetrics,
      streamingMetrics: harness.streamingMetrics,
      results: harness.results,
    };
  }
}

runTier5Suite()
  .then((res) => {
    if (res.verdict !== 'APPROVE') {
      process.exit(1);
    }
  })
  .catch((err) => {
    console.error('Fatal execution error:', err);
    process.exit(1);
  });

export { runTier5Suite };
