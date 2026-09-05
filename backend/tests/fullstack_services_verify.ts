/**
 * Fullstack Backend Verification Test Suite
 * Tests Auth, Sessions, Notes, Telemetry, History LWW Sync, Database Hydration, and Prisma SQLite integration.
 */

import { prisma } from '../lib/prisma';
import {
  hashPassword,
  comparePassword,
  signAccessToken,
  signRefreshToken,
  verifyJwt,
  issueDeviceToken,
  authenticateRequest,
  createSession,
  getActiveSessionsCount,
  listActiveSessions,
} from '../lib/auth';
import { notesStore, NoteItem } from '../lib/notes';
import { telemetryStore } from '../lib/telemetry';
import { historyStore, HistoryItem } from '../lib/storage';
import { CORS_HEADERS } from '../lib/cors';

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

async function runFullstackSuite() {
  console.log('=== STARTING FULLSTACK SERVICES INTEGRITY AUDIT ===\n');

  // TEST 1: Password Hashing & JWT Auth
  console.log('--- Checking Password Hashing & JWT Engine ---');
  const password = 'SuperSecurePassword2026!';
  const hashed = await hashPassword(password);
  assert(typeof hashed === 'string' && hashed.startsWith('$2'), 'Password hashed with bcrypt');
  assert(await comparePassword(password, hashed), 'Password comparison matches correct password');
  assert(!(await comparePassword('wrong-password', hashed)), 'Password comparison rejects incorrect password');

  const accessToken = await signAccessToken({
    sub: 'user-uuid-1234',
    email: 'test@liquidcalc.local',
    role: 'user',
    type: 'user',
  });
  assert(typeof accessToken === 'string' && accessToken.split('.').length === 3, 'Access token is valid JWT format');

  const decoded = await verifyJwt(accessToken);
  assert(decoded !== null, 'Access token successfully verified');
  assert(decoded?.sub === 'user-uuid-1234', 'Decoded subject matches user UUID');
  assert(decoded?.email === 'test@liquidcalc.local', 'Decoded email matches');

  const refreshToken = await signRefreshToken({
    sub: 'user-uuid-1234',
    type: 'user',
  });
  const decodedRefresh = await verifyJwt(refreshToken);
  assert(decodedRefresh !== null && decodedRefresh.sub === 'user-uuid-1234', 'Refresh token verified');

  // TEST 2: Active Session Management
  console.log('\n--- Checking Session Management Engine ---');
  const sessionUser = await prisma.user.create({
    data: {
      email: `session_user_${Date.now()}@liquidcalc.local`,
      passwordHash: hashed,
      name: 'Session Auditor',
      role: 'user',
    },
  });
  const userSession = await createSession({
    token: `sess_tok_${Date.now()}`,
    userId: sessionUser.id,
    expiresInDays: 7,
  });
  assert(userSession !== null && userSession.userId === sessionUser.id, 'Active user session created');

  const activeSessionsCount = await getActiveSessionsCount();
  assert(activeSessionsCount >= 1, 'Active session count is tracked');

  const activeSessionsList = await listActiveSessions(10);
  assert(activeSessionsList.length >= 1, 'Active sessions list returned with relations');
  assert(activeSessionsList.some((s) => s.userId === sessionUser.id), 'Active session found in list');

  // TEST 3: Mobile Device Token Issue & Verification
  console.log('\n--- Checking Mobile Device Token Service ---');
  const testDeviceId = `iPhone16,2_Audit_${Date.now()}`;
  const deviceResult = await issueDeviceToken({
    deviceId: testDeviceId,
    platform: 'ios',
    name: 'iPhone 16 Pro Max',
    userId: sessionUser.id,
  });
  assert(typeof deviceResult.token === 'string', 'Device token issued');
  assert(deviceResult.device.deviceId === testDeviceId, 'Device ID registered correctly');

  const verifiedDevice = await verifyJwt(deviceResult.token);
  assert(verifiedDevice !== null && verifiedDevice.type === 'device', 'Device token verified with device type');
  assert(verifiedDevice?.deviceId === testDeviceId, 'Verified device token contains deviceId');

  // TEST 4: Request Authenticator Helper (Headers & Query Params)
  console.log('\n--- Checking Request Authenticator Engine ---');
  // Bearer token
  const bearerReq = new Request('http://localhost/api/auth/profile', {
    headers: { authorization: `Bearer ${accessToken}` },
  });
  const authBearerResult = await authenticateRequest(bearerReq);
  assert(authBearerResult.authenticated === true, 'Bearer JWT request authenticated');
  assert(authBearerResult.type === 'user', 'Authenticated entity type is user');

  // Device token header
  const devReq = new Request('http://localhost/api/history/sync', {
    headers: { 'x-device-token': deviceResult.token },
  });
  const authDevResult = await authenticateRequest(devReq);
  assert(authDevResult.authenticated === true, 'Device token header authenticated');
  assert(authDevResult.type === 'device', 'Authenticated entity type is device');

  // Query parameter token
  const queryTokenReq = new Request(`http://localhost/api/auth/profile?token=${accessToken}`);
  const authQueryTokenResult = await authenticateRequest(queryTokenReq);
  assert(authQueryTokenResult.authenticated === true, 'URL query token authenticated');
  assert(authQueryTokenResult.type === 'user', 'Query token authenticated as user');

  // Query parameter API key
  const queryKeyReq = new Request('http://localhost/api/history?apiKey=lqc_live_system_test_123');
  const authQueryKeyResult = await authenticateRequest(queryKeyReq);
  assert(authQueryKeyResult.authenticated === true, 'URL query API key authenticated');
  assert(authQueryKeyResult.type === 'apikey', 'Query API key authenticated as apikey');

  // Invalid token
  const badReq = new Request('http://localhost/api/auth/profile', {
    headers: { authorization: 'Bearer invalid.token.value' },
  });
  const authBadResult = await authenticateRequest(badReq);
  assert(authBadResult.authenticated === false, 'Invalid Bearer token rejected');

  // TEST 5: CORS Configuration & Preflight Headers
  console.log('\n--- Checking CORS Allow-Headers ---');
  const allowHeaders = CORS_HEADERS['Access-Control-Allow-Headers'] || '';
  assert(allowHeaders.includes('x-api-key'), 'CORS allows x-api-key header');
  assert(allowHeaders.includes('x-device-token'), 'CORS allows x-device-token header');
  assert(allowHeaders.includes('Authorization'), 'CORS allows Authorization header');

  // TEST 6: Math Notes Engine & Conflict Resolution & User Linking
  console.log('\n--- Checking Math Notes Engine & Conflict Resolution ---');
  const noteId1 = `note-audit-${Date.now()}-1`;
  const note1: NoteItem = {
    id: noteId1,
    title: 'Euler Formula and Trigonometry',
    markdown: '$$e^{ix} = \\cos(x) + i\\sin(x)$$',
    tags: ['calculus', 'complex-analysis'],
    attachments: [
      {
        id: 'att-euler',
        kind: 'aiAnswer',
        summary: 'Proof of Euler Formula',
        createdAt: '2026-09-02T01:00:00.000Z',
      },
    ],
    createdAt: '2026-09-02T01:00:00.000Z',
    updatedAt: '2026-09-02T01:00:00.000Z',
    deviceId: testDeviceId,
    userId: sessionUser.id,
  };

  const noteSyncRes = await notesStore.sync([note1], testDeviceId, undefined, sessionUser.id);
  assert(noteSyncRes.success === true, 'Notes sync returned success');
  assert(noteSyncRes.syncedCount === 1, '1 note synced');

  // Search by query
  const searchNote = notesStore.list({ search: 'Euler Formula' });
  assert(searchNote.items.length >= 1, 'Search finds note by content or title');

  // Search by tag
  const tagNote = notesStore.list({ tag: 'complex-analysis' });
  assert(tagNote.items.length >= 1, 'Filter finds note by tag');

  // Filter by userId
  const userNotes = notesStore.list({ userId: sessionUser.id });
  assert(userNotes.items.length >= 1, 'Filter finds note by userId');

  // Conflict Resolution (LWW): update with newer timestamp
  const updatedNote: NoteItem = {
    id: noteId1,
    title: 'Euler Formula (Updated)',
    markdown: '$$e^{i\\pi} + 1 = 0$$',
    tags: ['calculus', 'identity'],
    attachments: [],
    createdAt: '2026-09-02T01:00:00.000Z',
    updatedAt: '2026-09-02T02:00:00.000Z',
    deviceId: testDeviceId,
    userId: sessionUser.id,
  };
  const updateSync = await notesStore.sync([updatedNote], testDeviceId);
  assert(updateSync.syncedCount === 1, 'Updated note accepted');
  const fetchedUpdated = notesStore.get(noteId1);
  assert(fetchedUpdated?.title === 'Euler Formula (Updated)', 'Note title updated via LWW');

  // Deletion (Tombstone)
  const deleted = notesStore.delete(noteId1);
  assert(deleted === true, 'Note deleted successfully');
  assert(notesStore.get(noteId1) === null, 'Deleted note omitted from active list');

  // TEST 7: History Sync with User Association & Direct Update
  console.log('\n--- Checking History Store Engine & Updates ---');
  const calcId1 = `calc-audit-${Date.now()}`;
  const syncHistRes = historyStore.sync(
    [
      {
        id: calcId1,
        timestamp: new Date().toISOString(),
        expression: 'integrate(cos(x), 0, pi/2)',
        result: '1',
        mode: 'calculus',
        notes: 'Definite integral of cos(x)',
        deviceId: testDeviceId,
      },
    ],
    testDeviceId,
    undefined,
    sessionUser.id
  );
  assert(syncHistRes.success === true, 'History item synced with userId');
  const storedCalc = historyStore.get(calcId1);
  assert(storedCalc?.result === '1', 'History item stored in map');

  const updatedCalc = historyStore.update(calcId1, { notes: 'Updated calculus note via PUT' });
  assert(updatedCalc?.notes === 'Updated calculus note via PUT', 'History item updated via update method');

  // TEST 8: Database Bidirectional Hydration
  console.log('\n--- Checking Database Bidirectional Hydration ---');
  const directDbCalcId = `direct_db_calc_${Date.now()}`;
  await prisma.calculation.create({
    data: {
      id: directDbCalcId,
      expression: 'gamma(5)',
      result: '24',
      mode: 'calculus',
      notes: 'Direct SQLite insertion test',
      deviceId: testDeviceId,
      userId: sessionUser.id,
    },
  });

  // Hydrate store from database
  await historyStore.hydrateFromDatabase();
  const hydratedCalc = historyStore.get(directDbCalcId);
  assert(hydratedCalc !== null && hydratedCalc.result === '24', 'Direct SQLite calculation hydrated into HistoryStore');

  const directDbNoteId = `direct_db_note_${Date.now()}`;
  await prisma.note.create({
    data: {
      id: directDbNoteId,
      title: 'Direct SQLite Note',
      markdown: 'Direct DB test note content',
      tags: JSON.stringify(['db-test', 'hydration']),
      attachments: JSON.stringify([]),
      deviceId: testDeviceId,
      userId: sessionUser.id,
    },
  });

  await notesStore.hydrateFromDatabase();
  const hydratedNote = notesStore.get(directDbNoteId);
  assert(hydratedNote !== null && hydratedNote.title === 'Direct SQLite Note', 'Direct SQLite note hydrated into NotesStore');

  // TEST 9: Telemetry Engine (Crashes, Performance, Usage)
  console.log('\n--- Checking Telemetry & Analytics Engine ---');
  const crashRecord = await telemetryStore.record({
    type: 'crash',
    name: 'ArithmeticOverflowException',
    payload: { stack: 'at MatrixMul (lib.rs:12)', expression: '9999^9999' },
    deviceId: testDeviceId,
    appVersion: '2.3.0',
    osVersion: 'iOS 18.2',
  });
  assert(crashRecord.id.startsWith('tel_'), 'Crash event generated telemetry ID');
  assert(crashRecord.type === 'crash', 'Event type is crash');

  const perfRecord = await telemetryStore.record({
    type: 'performance',
    name: 'fft_spectral_compute',
    payload: { durationMs: 45, samples: 1024 },
    deviceId: testDeviceId,
    appVersion: '2.3.0',
  });
  assert(perfRecord.type === 'performance', 'Performance event recorded');

  const stats = telemetryStore.getStats();
  assert(stats.success === true, 'Telemetry stats returned');
  assert(stats.totalEvents >= 2, 'Telemetry records tracked');
  assert(stats.countsByType.crash >= 1, 'Crash count tracked');
  assert(typeof stats.averagePerformanceLatencyMs === 'number', 'Average performance latency calculated');

  // TEST 10: SQLite Database & User Profile Relation Count
  console.log('\n--- Checking User Profile Relations Count in SQLite ---');
  const userWithCounts = await prisma.user.findUnique({
    where: { id: sessionUser.id },
    include: {
      _count: {
        select: {
          calculations: true,
          notes: true,
          sessions: true,
        },
      },
    },
  });
  assert(userWithCounts !== null, 'Found user in SQLite');
  assert(userWithCounts!._count.calculations >= 1, 'User calculations count in database is at least 1');
  assert(userWithCounts!._count.notes >= 1, 'User notes count in database is at least 1');
  assert(userWithCounts!._count.sessions >= 1, 'User sessions count in database is at least 1');

  console.log(`\n========================================`);
  console.log(`FULLSTACK AUDIT SUMMARY:`);
  console.log(`Passed Checks: ${passed}`);
  console.log(`Failed Checks: ${failed}`);
  console.log(`Binary Verdict: ${failed === 0 ? 'CLEAN (ALL FULLSTACK SERVICES 100% OPERATIONAL)' : 'FAILURE'}`);
  console.log(`========================================\n`);

  await prisma.$disconnect();
}

runFullstackSuite().catch(async (err) => {
  console.error('Fatal Fullstack Error:', err);
  await prisma.$disconnect().catch(() => {});
  process.exit(1);
});
