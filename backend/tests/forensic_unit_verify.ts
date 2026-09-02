import { generateIosManifestXml, buildItmsServicesUrl, DEFAULT_BUNDLE_ID, DEFAULT_APP_NAME, DEFAULT_VERSION, DEFAULT_IPA_URL } from '../lib/ota';
import { historyStore, HistoryItem } from '../lib/storage';
import { resolveGeminiApiKey, parseBase64Image, extractCleanJson, buildGeminiPayload, solveStructured } from '../lib/gemini';
import { CORS_HEADERS, handleOptions, jsonResponse } from '../lib/cors';

let passed = 0;
let failed = 0;

function assert(condition: boolean, msg: string) {
  if (!condition) {
    console.error(`❌ FAIL: ${msg}`);
    failed++;
    throw new Error(msg);
  } else {
    console.log(`✅ PASS: ${msg}`);
    passed++;
  }
}

async function runForensicAudit() {
  console.log('=== STARTING FORENSIC INTEGRITY CHECKS ===\n');

  // CHECK 1: CORS Handlers & Headers
  console.log('--- Checking CORS Utility ---');
  assert(CORS_HEADERS['Access-Control-Allow-Origin'] === '*', 'CORS Allow-Origin is wildcard');
  assert(CORS_HEADERS['Access-Control-Allow-Methods'].includes('POST'), 'CORS Allow-Methods has POST');
  assert(CORS_HEADERS['Access-Control-Allow-Headers'].includes('x-gemini-api-key'), 'CORS Headers includes x-gemini-api-key');
  
  const optRes = handleOptions();
  assert(optRes.status === 204, 'handleOptions returns 204 No Content');
  assert(optRes.headers.get('Access-Control-Allow-Origin') === '*', 'handleOptions attaches CORS');

  const jRes = jsonResponse({ status: 'ok' });
  assert(jRes.status === 200, 'jsonResponse defaults to 200');
  assert(jRes.headers.get('Content-Type')?.includes('application/json') === true, 'jsonResponse sets application/json');

  // CHECK 2: OTA Manifest Generator & XML Sanitization
  console.log('\n--- Checking OTA Generator & XML Entity Escaping ---');
  const defaultXml = generateIosManifestXml();
  assert(defaultXml.includes('<!DOCTYPE plist'), 'Manifest includes Apple DTD');
  assert(defaultXml.includes(DEFAULT_BUNDLE_ID), 'Manifest embeds default bundle ID');
  assert(defaultXml.includes(DEFAULT_APP_NAME), 'Manifest embeds default app name');
  assert(defaultXml.includes(DEFAULT_VERSION), 'Manifest embeds default version');
  assert(defaultXml.includes(DEFAULT_IPA_URL), 'Manifest embeds default IPA URL');

  const customSpecialXml = generateIosManifestXml({
    bundleId: 'com.liquidcalc.test<>&',
    name: 'Liquid & Calc "Pro" <Beta>',
    version: '2.3.0 & 1',
  });
  assert(customSpecialXml.includes('com.liquidcalc.test&lt;&gt;&amp;'), 'bundleId special chars properly escaped');
  assert(customSpecialXml.includes('Liquid &amp; Calc &quot;Pro&quot; &lt;Beta&gt;'), 'app name special chars properly escaped');
  assert(customSpecialXml.includes('2.3.0 &amp; 1'), 'version special chars properly escaped');
  assert(!customSpecialXml.includes(' <Beta>'), 'Raw unescaped tags absent in XML');

  const itmsUrl = buildItmsServicesUrl('https://liquidcalc.vercel.app/api/ota/manifest?v=2.3.0');
  assert(itmsUrl.startsWith('itms-services://?action=download-manifest&url='), 'itms-services URL scheme formatted properly');
  assert(itmsUrl.includes(encodeURIComponent('https://liquidcalc.vercel.app/api/ota/manifest?v=2.3.0')), 'itms-services URL target properly URI-encoded');

  // CHECK 3: Calculation History Engine & UUID Management
  console.log('\n--- Checking History Storage Engine ---');
  const initialStats = historyStore.getStats();
  assert(initialStats.totalCount >= 6, 'Seed items present in history store');

  const testSyncBatch: HistoryItem[] = [
    {
      id: 'unit-test-uuid-001',
      timestamp: '2026-09-02T06:00:00.000Z',
      expression: 'sin(pi / 2)',
      result: '1',
      mode: 'calculus',
      notes: 'Trigonometric exact value',
      deviceId: 'Device-Alpha',
    },
    {
      id: 'unit-test-uuid-002',
      timestamp: '2026-09-02T06:05:00.000Z',
      expression: '0xFF | 0x00',
      result: '255',
      mode: 'programmer',
      notes: 'Bitwise OR',
      deviceId: 'Device-Beta',
    },
  ];

  const syncRes = historyStore.sync(testSyncBatch, 'Device-Alpha');
  assert(syncRes.success === true, 'Sync returns success');
  assert(syncRes.syncedCount === 2, 'Sync reports 2 items synced');

  // Duplicate ID sync with updated note
  const updateBatch: HistoryItem[] = [
    {
      id: 'unit-test-uuid-001',
      timestamp: '2026-09-02T06:10:00.000Z',
      expression: 'sin(pi / 2)',
      result: '1',
      mode: 'calculus',
      notes: 'Updated Note after Recalculation',
      deviceId: 'Device-Alpha',
    },
  ];
  const updateRes = historyStore.sync(updateBatch);
  assert(updateRes.syncedCount === 1, 'Syncing existing ID updates record without duplicating count');

  // Verify list filtering by mode
  const calculusList = historyStore.list({ mode: 'calculus' });
  assert(calculusList.items.every((i) => i.mode === 'calculus'), 'Mode filter calculus returns only calculus items');
  assert(calculusList.items.some((i) => i.id === 'unit-test-uuid-001'), 'Calculus item found in list');

  // Verify list filtering by deviceId
  const betaList = historyStore.list({ deviceId: 'Device-Beta' });
  assert(betaList.items.length === 1 && betaList.items[0].id === 'unit-test-uuid-002', 'Device filter works');

  // Verify search
  const searchList = historyStore.list({ search: 'Bitwise OR' });
  assert(searchList.items.length >= 1 && Boolean(searchList.items[0].notes?.includes('Bitwise OR')), 'Search filtering works on notes');

  // Verify pagination & offset
  const page1 = historyStore.list({ limit: 2, offset: 0 });
  assert(page1.items.length === 2, 'Page 1 limit=2 returns 2 items');
  const page2 = historyStore.list({ limit: 2, offset: 2 });
  assert(page2.items.length === 2, 'Page 2 limit=2 returns 2 items');
  assert(page1.items[0].id !== page2.items[0].id, 'Page 1 and Page 2 items are distinct');

  // Out of bounds pagination
  const pageOob = historyStore.list({ limit: 10, offset: 1000 });
  assert(pageOob.items.length === 0, 'Out of bounds offset returns empty items array');
  assert(pageOob.total > 0, 'Total count remains accurate on OOB offset');

  // CHECK 4: Gemini AI Key Resolver & Multimodal Image Parsing
  console.log('\n--- Checking Gemini Key Resolver & Multimodal Payload Engine ---');
  // Env fallback
  const origEnv = process.env.GEMINI_API_KEY;
  process.env.GEMINI_API_KEY = 'env-secret-key-123';
  assert(resolveGeminiApiKey() === 'env-secret-key-123', 'Resolves key from process.env.GEMINI_API_KEY');

  // Custom header override
  process.env.GEMINI_API_KEY = '';
  const mockReqHeader = new Request('http://localhost', {
    headers: { 'x-gemini-api-key': 'header-key-456' },
  });
  assert(resolveGeminiApiKey(mockReqHeader) === 'header-key-456', 'Resolves key from x-gemini-api-key header');

  // Authorization Bearer override
  const mockReqAuth = new Request('http://localhost', {
    headers: { authorization: 'Bearer bearer-key-789' },
  });
  assert(resolveGeminiApiKey(mockReqAuth) === 'bearer-key-789', 'Resolves key from Authorization Bearer header');

  // Restore env
  process.env.GEMINI_API_KEY = origEnv;

  // Base64 Image parser
  const parsedDataUrl = parseBase64Image('data:image/png;base64,iVBORw0KGgoAAAANSUhEUg==');
  assert(parsedDataUrl.mimeType === 'image/png', 'Parsed data URL mimeType is image/png');
  assert(parsedDataUrl.data === 'iVBORw0KGgoAAAANSUhEUg==', 'Parsed data URL extracted base64 data');

  const parsedRaw = parseBase64Image('/9j/4AAQSkZJRgABAQEASABIAAD/');
  assert(parsedRaw.mimeType === 'image/jpeg', 'Parsed raw base64 defaults to image/jpeg');
  assert(parsedRaw.data === '/9j/4AAQSkZJRgABAQEASABIAAD/', 'Parsed raw base64 preserved string');

  // JSON code fence extractor
  assert(extractCleanJson('```json\n{"status": "ok"}\n```') === '{"status": "ok"}', 'Cleaned ```json code fences');
  assert(extractCleanJson('```\n{"status": "ok"}\n```') === '{"status": "ok"}', 'Cleaned ``` code fences');
  assert(extractCleanJson('{"status": "ok"}') === '{"status": "ok"}', 'Leaves clean JSON untouched');

  // Payload builder
  const payload = buildGeminiPayload({
    prompt: 'Integrate x^2 dx',
    history: [{ role: 'user', text: 'Hello' }, { role: 'model', text: 'Hi! What math do you want to solve?' }],
    temperature: 0.1,
  });
  assert(payload.contents.length === 3, 'Payload contents includes history and current prompt');
  assert(payload.generationConfig.temperature === 0.1, 'Payload generationConfig respects temperature');
  assert(payload.system_instruction.parts[0].text.includes('LiquidCalc AI'), 'Payload embeds LiquidCalc system prompt');

  // Structured Solver Fallback
  console.log('\n--- Checking Structured Math & Receipt Fallback Engine ---');
  const mathFallback = await solveStructured({
    mode: 'math',
    expression: '15 + 25 * 2',
    apiKey: 'invalid-key-to-trigger-fallback',
  });
  assert(mathFallback.success === true, 'Math solver returns success');
  assert(mathFallback.mode === 'math', 'Math solver mode is math');
  assert('result' in mathFallback && mathFallback.result === '65', 'Math fallback correctly evaluates arithmetic');
  assert('steps' in mathFallback && Array.isArray(mathFallback.steps) && mathFallback.steps.length > 0, 'Math fallback provides steps');

  const receiptFallback = await solveStructured({
    mode: 'receipt',
    prompt: 'Receipt for lunch',
    apiKey: 'invalid-key-to-trigger-fallback',
  });
  assert(receiptFallback.success === true, 'Receipt solver returns success');
  assert(receiptFallback.mode === 'receipt', 'Receipt solver mode is receipt');
  assert('items' in receiptFallback && receiptFallback.items.length >= 2, 'Receipt fallback returns parsed item list');
  assert('total' in receiptFallback && receiptFallback.total > 0, 'Receipt fallback calculates total');

  console.log(`\n========================================`);
  console.log(`FORENSIC AUDIT SUMMARY:`);
  console.log(`Passed Checks: ${passed}`);
  console.log(`Failed Checks: ${failed}`);
  console.log(`Binary Verdict: ${failed === 0 ? 'CLEAN (NO INTEGRITY VIOLATIONS)' : 'INTEGRITY VIOLATION'}`);
  console.log(`========================================\n`);
}

runForensicAudit().catch((err) => {
  console.error('Fatal Forensic Error:', err);
  process.exit(1);
});
