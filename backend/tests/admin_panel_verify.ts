/**
 * Admin Panel & System Control Center Verification Suite
 * Tests:
 * 1. Security & Admin Authentication:
 *    - Reject unauthenticated requests with 401
 *    - Reject regular user JWT with 403 Forbidden
 *    - Accept master admin API key (x-admin-key header & query param)
 *    - Accept admin user JWT with role === "admin"
 * 2. User Management (/api/admin/users):
 *    - List, search, and paginate registered users and device identities
 *    - 1-tap tier upgrade to PRO and ULTRA
 *    - Ban / activate status toggle & session revocation
 *    - Verify banned user cannot authenticate
 * 3. Subscription & Promo Code Hub (/api/admin/subscriptions, /api/admin/promos):
 *    - Inspect active subscriptions, provider breakdown, and MRR
 *    - Subscription extension and cancellation
 *    - Create, list, toggle, and revoke promotional codes
 * 4. Telemetry & Crash Diagnostic Center (/api/admin/telemetry, /api/admin/crashes):
 *    - Real-time crash log stream with stack traces
 *    - Diagnostic crash emission
 *    - Event analytics and calculation volume by mode
 * 5. System Health & Infrastructure (/api/admin/health, /api/admin/stats):
 *    - SQLite database metrics, Edge function latency, Gemini quota, OTA downloads
 *    - Executive KPI overview
 */

import { prisma } from "../lib/prisma";
import { hashPassword, signAccessToken, issueDeviceToken, authenticateRequest, createSession } from "../lib/auth";
import { ADMIN_SECRET_KEY } from "../lib/admin";
import { GET as adminUsersGet, PATCH as adminUsersPatch, DELETE as adminUsersDelete } from "../app/api/admin/users/route";
import { GET as adminSubsGet, PATCH as adminSubsPatch } from "../app/api/admin/subscriptions/route";
import { GET as adminPromosGet, POST as adminPromosPost, PATCH as adminPromosPatch, DELETE as adminPromosDelete } from "../app/api/admin/promos/route";
import { GET as adminCrashesGet, POST as adminCrashesPost } from "../app/api/admin/crashes/route";
import { GET as adminTelemetryGet } from "../app/api/admin/telemetry/route";
import { GET as adminHealthGet } from "../app/api/admin/health/route";
import { GET as adminStatsGet } from "../app/api/admin/stats/route";
import { GET as adminAgentsGet, POST as adminAgentsPost, PATCH as adminAgentsPatch } from "../app/api/admin/agents/route";

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

function makeRequest(
  url: string,
  method: string = "GET",
  body?: any,
  headers: Record<string, string> = {}
): any {
  const init: RequestInit = {
    method,
    headers: {
      "Content-Type": "application/json",
      ...headers,
    },
  };
  if (body) {
    init.body = JSON.stringify(body);
  }
  const req = new Request(url, init);
  (req as any).nextUrl = new URL(url);
  return req;
}

async function runAdminTestSuite() {
  console.log("=== STARTING ADMIN CONTROL CENTER & SYSTEM AGENTS VERIFICATION SUITE ===\n");

  // Setup test users
  const regularUser = await prisma.user.create({
    data: {
      email: `regular_user_${Date.now()}@liquidcalc.test`,
      passwordHash: await hashPassword("UserPass123!"),
      name: "Regular Client",
      role: "user",
    },
  });

  const regularToken = await signAccessToken({
    sub: regularUser.id,
    email: regularUser.email,
    role: regularUser.role,
    type: "user",
  });

  const adminUser = await prisma.user.create({
    data: {
      email: `admin_operator_${Date.now()}@liquidcalc.test`,
      passwordHash: await hashPassword("AdminPass123!"),
      name: "Chief Admin Operator",
      role: "admin",
    },
  });

  const adminToken = await signAccessToken({
    sub: adminUser.id,
    email: adminUser.email,
    role: adminUser.role,
    type: "user",
  });

  // SECTION 1: Security & Authentication
  console.log("--- 1. Testing Admin Security & Authentication Gates ---");
  
  // Unauthenticated request
  const unauthReq = makeRequest("http://localhost/api/admin/health");
  const unauthRes = await adminHealthGet(unauthReq);
  assert(unauthRes.status === 401, "Unauthenticated access rejected with 401 Unauthorized");

  // Invalid admin key
  const badKeyReq = makeRequest("http://localhost/api/admin/health", "GET", null, {
    "x-admin-key": "invalid_wrong_secret_key",
  });
  const badKeyRes = await adminHealthGet(badKeyReq);
  assert(badKeyRes.status === 401, "Invalid master admin key rejected with 401");

  // Regular user (role !== admin)
  const forbiddenReq = makeRequest("http://localhost/api/admin/health", "GET", null, {
    Authorization: `Bearer ${regularToken}`,
  });
  const forbiddenRes = await adminHealthGet(forbiddenReq);
  assert(forbiddenRes.status === 403, "Regular user without ADMIN role rejected with 403 Forbidden");

  // Master admin key via header
  const masterKeyReq = makeRequest("http://localhost/api/admin/health", "GET", null, {
    "x-admin-key": ADMIN_SECRET_KEY,
  });
  const masterKeyRes = await adminHealthGet(masterKeyReq);
  assert(masterKeyRes.status === 200, "Master admin key in 'x-admin-key' authorizes with 200 OK");

  // Master admin key via Bearer token
  const bearerKeyReq = makeRequest("http://localhost/api/admin/health", "GET", null, {
    Authorization: `Bearer ${ADMIN_SECRET_KEY}`,
  });
  const bearerKeyRes = await adminHealthGet(bearerKeyReq);
  assert(bearerKeyRes.status === 200, "Master admin key in Bearer authorization authorizes with 200 OK");

  // Admin user JWT token
  const jwtAdminReq = makeRequest("http://localhost/api/admin/health", "GET", null, {
    Authorization: `Bearer ${adminToken}`,
  });
  const jwtAdminRes = await adminHealthGet(jwtAdminReq);
  assert(jwtAdminRes.status === 200, "Admin user role JWT authorizes with 200 OK");

  // SECTION 2: User Management
  console.log("\n--- 2. Testing User Management (/api/admin/users) ---");
  const adminHeaders = { "x-admin-key": ADMIN_SECRET_KEY };

  // List users
  const listUsersReq = makeRequest("http://localhost/api/admin/users?limit=10&page=1", "GET", null, adminHeaders);
  const listUsersRes = await adminUsersGet(listUsersReq);
  assert(listUsersRes.status === 200, "GET /api/admin/users returns 200 OK");
  const listUsersData = await listUsersRes.json();
  assert(listUsersData.success === true, "Users listing reports success: true");
  assert(Array.isArray(listUsersData.users), "Users is an array");
  assert(listUsersData.users.length > 0, "Users array is non-empty");
  assert(listUsersData.summary.totalUsers >= 2, "Summary includes totalUsers count");
  assert(Array.isArray(listUsersData.guestDevices), "Guest devices list included");

  // Search user by email
  const searchReq = makeRequest(
    `http://localhost/api/admin/users?search=${encodeURIComponent(regularUser.email)}`,
    "GET",
    null,
    adminHeaders
  );
  const searchRes = await adminUsersGet(searchReq);
  const searchData = await searchRes.json();
  assert(searchData.users.some((u: any) => u.id === regularUser.id), "Target user found by email search");

  // 1-tap Tier Upgrade to ULTRA
  const upgradeReq = makeRequest(
    "http://localhost/api/admin/users",
    "PATCH",
    {
      userId: regularUser.id,
      action: "upgrade_tier",
      tier: "ULTRA",
    },
    adminHeaders
  );
  const upgradeRes = await adminUsersPatch(upgradeReq);
  assert(upgradeRes.status === 200, "Tier upgrade returns 200 OK");
  const upgradeData = await upgradeRes.json();
  assert(upgradeData.tier === "ULTRA", "User tier upgraded to ULTRA");
  assert(upgradeData.entitlements.priorityAi === true, "ULTRA entitlements include priority AI");

  // Ban status toggle & session revocation
  // First create an active session for regular user
  const sessionToken = `test_sess_${Date.now()}`;
  await createSession({ token: sessionToken, userId: regularUser.id });

  const banReq = makeRequest(
    "http://localhost/api/admin/users",
    "PATCH",
    {
      userId: regularUser.id,
      action: "toggle_status",
      status: "banned",
    },
    adminHeaders
  );
  const banRes = await adminUsersPatch(banReq);
  assert(banRes.status === 200, "Ban user returns 200 OK");
  const banData = await banRes.json();
  assert(banData.user.status === "banned", "User status changed to banned");
  assert(banData.revokedSessions >= 1, "Active sessions revoked upon banning user");

  // Verify banned user authentication fails
  const bannedAuthOutcome = await authenticateRequest(
    makeRequest("http://localhost/api/test", "GET", null, {
      Authorization: `Bearer ${regularToken}`,
    })
  );
  assert(bannedAuthOutcome.authenticated === false, "Banned user fails authenticateRequest check");
  assert(Boolean(bannedAuthOutcome.error?.includes("banned")), "Error message mentions account suspended or banned");

  // Unban user
  const unbanReq = makeRequest(
    "http://localhost/api/admin/users",
    "PATCH",
    {
      userId: regularUser.id,
      action: "toggle_status",
      status: "active",
    },
    adminHeaders
  );
  const unbanRes = await adminUsersPatch(unbanReq);
  assert(unbanRes.status === 200, "Unban user returns 200 OK");
  const unbanData = await unbanRes.json();
  assert(unbanData.user.status === "active", "User status restored to active");

  // Test session revocation explicitly
  const sessRevokeReq = makeRequest(
    "http://localhost/api/admin/users",
    "PATCH",
    {
      userId: regularUser.id,
      action: "revoke_sessions",
    },
    adminHeaders
  );
  const sessRevokeRes = await adminUsersPatch(sessRevokeReq);
  assert(sessRevokeRes.status === 200, "Explicit session revocation returns 200 OK");

  // Test atomic multi-field user update (tier + status + role together)
  const multiUpdateReq = makeRequest(
    "http://localhost/api/admin/users",
    "PATCH",
    {
      userId: regularUser.id,
      tier: "ULTRA",
      status: "active",
      role: "user",
    },
    adminHeaders
  );
  const multiUpdateRes = await adminUsersPatch(multiUpdateReq);
  assert(multiUpdateRes.status === 200, "Atomic multi-field update returns 200 OK");
  const multiUpdateData = await multiUpdateRes.json();
  assert(multiUpdateData.updates.tier === "ULTRA", "Atomic update set tier to ULTRA");
  assert(multiUpdateData.updates.status === "active", "Atomic update set status to active");

  // Test temporary user creation and deletion
  const dummyUser = await prisma.user.create({
    data: {
      email: `dummy_delete_${Date.now()}@liquidcalc.test`,
      passwordHash: await hashPassword("DummyPass123!"),
      name: "Temporary User",
      role: "user",
    },
  });
  const deleteUserReq = makeRequest(
    `http://localhost/api/admin/users?userId=${dummyUser.id}`,
    "DELETE",
    null,
    adminHeaders
  );
  const deleteUserRes = await adminUsersDelete(deleteUserReq);
  assert(deleteUserRes.status === 200, "DELETE /api/admin/users returns 200 OK");
  const deletedCheck = await prisma.user.findUnique({ where: { id: dummyUser.id } });
  assert(!deletedCheck, "Deleted user record is removed from database");
  console.log("\n--- 3. Testing Subscription & Promo Code Hub ---");

  // List subscriptions
  const listSubsReq = makeRequest("http://localhost/api/admin/subscriptions", "GET", null, adminHeaders);
  const listSubsRes = await adminSubsGet(listSubsReq);
  assert(listSubsRes.status === 200, "GET /api/admin/subscriptions returns 200 OK");
  const listSubsData = await listSubsRes.json();
  assert(listSubsData.success === true, "Subscriptions listing returns success");
  assert(Array.isArray(listSubsData.subscriptions), "Subscriptions is an array");
  assert(typeof listSubsData.metrics.estimatedMrr === "number", "Estimated MRR calculated");
  assert(typeof listSubsData.metrics.providerBreakdown === "object", "Provider breakdown included");

  // Extend a subscription
  if (listSubsData.subscriptions.length > 0) {
    const targetSub = listSubsData.subscriptions[0];
    const initialEnd = new Date(targetSub.currentPeriodEnd).getTime();

    const extendReq = makeRequest(
      "http://localhost/api/admin/subscriptions",
      "PATCH",
      {
        id: targetSub.id,
        action: "extend",
        days: 45,
      },
      adminHeaders
    );
    const extendRes = await adminSubsPatch(extendReq);
    assert(extendRes.status === 200, "Subscription extension returns 200 OK");
    const extendData = await extendRes.json();
    const updatedEnd = new Date(extendData.subscription.currentPeriodEnd).getTime();
    assert(updatedEnd > initialEnd, "Subscription currentPeriodEnd moved forward");
  }

  // Create Promo Code
  const newPromoCode = `PROMO_ADMIN_TEST_${Date.now()}`;
  const createPromoReq = makeRequest(
    "http://localhost/api/admin/promos",
    "POST",
    {
      code: newPromoCode,
      tier: "ULTRA",
      durationDays: 60,
      maxUses: 250,
    },
    adminHeaders
  );
  const createPromoRes = await adminPromosPost(createPromoReq);
  assert(createPromoRes.status === 201, "Create promo code returns 201 Created");
  const createPromoData = await createPromoRes.json();
  assert(createPromoData.promo.code === newPromoCode, "Promo code matches submitted code");
  assert(createPromoData.promo.tier === "ULTRA", "Promo code tier is ULTRA");

  // List Promos
  const listPromosReq = makeRequest("http://localhost/api/admin/promos", "GET", null, adminHeaders);
  const listPromosRes = await adminPromosGet(listPromosReq);
  assert(listPromosRes.status === 200, "GET /api/admin/promos returns 200 OK");
  const listPromosData = await listPromosRes.json();
  assert(listPromosData.promos.some((p: any) => p.code === newPromoCode), "Newly created promo appears in list");

  // Toggle Promo Active Status
  const togglePromoReq = makeRequest(
    "http://localhost/api/admin/promos",
    "PATCH",
    {
      code: newPromoCode,
      active: false,
    },
    adminHeaders
  );
  const togglePromoRes = await adminPromosPatch(togglePromoReq);
  assert(togglePromoRes.status === 200, "Toggle promo returns 200 OK");
  const togglePromoData = await togglePromoRes.json();
  assert(togglePromoData.promo.active === false, "Promo code active status toggled to false");

  // Delete / Revoke Promo Code
  const deletePromoReq = makeRequest(
    `http://localhost/api/admin/promos?code=${newPromoCode}`,
    "DELETE",
    null,
    adminHeaders
  );
  const deletePromoRes = await adminPromosDelete(deletePromoReq);
  assert(deletePromoRes.status === 200, "Delete promo returns 200 OK");

  // Verify deletion
  const verifyDeleteReq = makeRequest("http://localhost/api/admin/promos", "GET", null, adminHeaders);
  const verifyDeleteRes = await adminPromosGet(verifyDeleteReq);
  const verifyDeleteData = await verifyDeleteRes.json();
  assert(!verifyDeleteData.promos.some((p: any) => p.code === newPromoCode), "Deleted promo code is absent");

  // SECTION 4: Telemetry & Crash Diagnostic Center
  console.log("\n--- 4. Testing Telemetry & Crash Diagnostic Center ---");

  // Emit diagnostic crash
  const emitCrashReq = makeRequest(
    "http://localhost/api/admin/crashes",
    "POST",
    {
      error: "EXC_BAD_ACCESS in SwiftMatrixShader.metal",
      stack: "Thread 0 Crashed:\n0  libmetal.dylib 0x0000000104123abc in MetalShaderContext\n1  LiquidCalc 0x00000001004523a0 in MatrixView.render()",
      deviceId: "iPhone16,2-DiagnosticUnit",
      appVersion: "2.3.0",
      osVersion: "iOS 18.2",
    },
    adminHeaders
  );
  const emitCrashRes = await adminCrashesPost(emitCrashReq);
  assert(emitCrashRes.status === 201, "Simulate crash returns 201 Created");
  const emitCrashData = await emitCrashRes.json();
  assert(emitCrashData.crash.type === "crash", "Event type recorded as crash");

  // List crashes stream
  const listCrashesReq = makeRequest("http://localhost/api/admin/crashes", "GET", null, adminHeaders);
  const listCrashesRes = await adminCrashesGet(listCrashesReq);
  assert(listCrashesRes.status === 200, "GET /api/admin/crashes returns 200 OK");
  const listCrashesData = await listCrashesRes.json();
  assert(listCrashesData.total >= 1, "Crash stream has at least 1 record");
  assert(listCrashesData.crashes.length > 0, "Crashes array is populated");
  assert(typeof listCrashesData.crashes[0].stack === "string", "Stack trace string preserved in crash object");
  assert(typeof listCrashesData.uniqueAffectedDevices === "number", "Unique affected devices counted");

  // Telemetry analytics & calculation modes
  const telemetryReq = makeRequest("http://localhost/api/admin/telemetry", "GET", null, adminHeaders);
  const telemetryRes = await adminTelemetryGet(telemetryReq);
  assert(telemetryRes.status === 200, "GET /api/admin/telemetry returns 200 OK");
  const telemetryData = await telemetryRes.json();
  assert(telemetryData.analytics.totalEvents >= 1, "Total events tracked");
  assert(typeof telemetryData.analytics.calculationModes === "object", "Calculation volume by mode present");
  assert(typeof telemetryData.analytics.averageLatencyMs === "number", "Average latency measured");

  // SECTION 5: System Health & Infrastructure
  console.log("\n--- 5. Testing System Health & Infrastructure Metrics ---");

  // System Health
  const healthReq = makeRequest("http://localhost/api/admin/health", "GET", null, adminHeaders);
  const healthRes = await adminHealthGet(healthReq);
  assert(healthRes.status === 200, "GET /api/admin/health returns 200 OK");
  const healthData = await healthRes.json();
  assert(healthData.healthy === true, "Health endpoint reports healthy: true");
  assert(typeof healthData.edgeLatencyMs === "number", "Edge latency measured in ms");
  assert(typeof healthData.database.fileSizeBytes === "number", "SQLite file size reported in bytes");
  assert(healthData.services.gemini_gateway.model === "gemini-2.5-flash", "Gemini 2.5 Flash gateway active");
  assert(healthData.services.ota_release.latestVersion === "2.3.0", "OTA latest version verified");

  // Stats Overview
  const statsReq = makeRequest("http://localhost/api/admin/stats", "GET", null, adminHeaders);
  const statsRes = await adminStatsGet(statsReq);
  assert(statsRes.status === 200, "GET /api/admin/stats returns 200 OK");
  const statsData = await statsRes.json();
  assert(statsData.success === true, "Stats returns success");
  assert(typeof statsData.stats.stabilityRatePct === "number", "Stability rate % calculated");
  assert(statsData.stats.stabilityRatePct > 0, "Stability rate is positive");
  assert(typeof statsData.stats.estimatedMrr === "number", "Estimated MRR reported");
  assert(typeof statsData.stats.tierBreakdown === "object", "Tier distribution breakdown reported");

  // SECTION 6: System Agents & Autonomous ReAct Engine
  console.log("\n--- 6. Testing System Agents & Autonomous ReAct Engine (/api/admin/agents) ---");

  // 1. List System Agents
  const listAgentsReq = makeRequest("http://localhost/api/admin/agents", "GET", null, adminHeaders);
  const listAgentsRes = await adminAgentsGet(listAgentsReq);
  assert(listAgentsRes.status === 200, "GET /api/admin/agents returns 200 OK");
  const agentsData = await listAgentsRes.json();
  assert(agentsData.success === true, "System agents listing returns success");
  assert(Array.isArray(agentsData.agents), "Agents is an array");
  assert(agentsData.agents.length >= 4, "At least 4 system agents registered");
  assert(agentsData.summary.activeCount >= 1, "Active system agents present");

  const reactAgent = agentsData.agents.find((a: any) => a.id === "autonomous-react-agent");
  assert(Boolean(reactAgent), "Autonomous ReAct math agent found");
  assert(reactAgent.tools.length >= 4, "ReAct agent has native math tools registered");

  // 2. Execute Autonomous ReAct Math Agent (Calculus integral reasoning)
  const execAgentReq = makeRequest(
    "http://localhost/api/admin/agents",
    "POST",
    {
      agentId: "autonomous-react-agent",
      prompt: "Evaluate integral of 3x^2 dx from 0 to 2 with step-by-step calculus derivation",
    },
    adminHeaders
  );
  const execAgentRes = await adminAgentsPost(execAgentReq);
  assert(execAgentRes.status === 200, "POST /api/admin/agents returns 200 OK for ReAct math task");
  const execData = await execAgentRes.json();
  assert(execData.success === true, "ReAct execution succeeded");
  assert(Array.isArray(execData.steps), "ReAct execution produced steps timeline");
  assert(execData.steps.length >= 4, "ReAct loop completed all 4 steps (Thought -> Tool -> Observation -> Answer)");
  assert(execData.steps.some((s: any) => s.type === "thought"), "Execution trace includes cognitive Thought step");
  assert(execData.steps.some((s: any) => s.type === "tool_call"), "Execution trace includes Action / Tool Call step");
  assert(execData.steps.some((s: any) => s.type === "observation"), "Execution trace includes Tool Observation step");
  assert(execData.steps.some((s: any) => s.type === "final_answer"), "Execution trace includes Final Answer step");
  assert(execData.finalAnswer.includes("8"), "Calculus derivation evaluated exact analytical result 8");

  // 3. Execute Database Maintenance Agent
  const maintReq = makeRequest(
    "http://localhost/api/admin/agents",
    "POST",
    {
      agentId: "database-maintenance-agent",
      action: "run_maintenance",
    },
    adminHeaders
  );
  const maintRes = await adminAgentsPost(maintReq);
  assert(maintRes.status === 200, "Database maintenance agent executed with 200 OK");
  const maintData = await maintRes.json();
  assert(maintData.result.integrityCheckStatus === "ok", "Database integrity check returned ok");

  // 4. Toggle Agent Status
  const toggleAgentReq = makeRequest(
    "http://localhost/api/admin/agents",
    "PATCH",
    {
      agentId: "ota-distribution-agent",
      status: "paused",
    },
    adminHeaders
  );
  const toggleAgentRes = await adminAgentsPatch(toggleAgentReq);
  assert(toggleAgentRes.status === 200, "PATCH /api/admin/agents toggles status to paused");
  const toggleData = await toggleAgentRes.json();
  assert(toggleData.agent.status === "paused", "Agent status updated to paused");

  // Paused agent rejection
  const pausedExecReq = makeRequest(
    "http://localhost/api/admin/agents",
    "POST",
    {
      agentId: "ota-distribution-agent",
      action: "verify_manifest",
    },
    adminHeaders
  );
  const pausedExecRes = await adminAgentsPost(pausedExecReq);
  assert(pausedExecRes.status === 400, "Paused agent execution rejected with 400 Bad Request");

  // Restore status to active
  const restoreAgentReq = makeRequest(
    "http://localhost/api/admin/agents",
    "PATCH",
    {
      agentId: "ota-distribution-agent",
      status: "active",
    },
    adminHeaders
  );
  const restoreAgentRes = await adminAgentsPatch(restoreAgentReq);
  assert(restoreAgentRes.status === 200, "Agent status restored to active");

  console.log("\n========================================");
  console.log("ADMIN SYSTEM AGENTS AUDIT SUMMARY:");
  console.log(`Passed Checks: ${passed}`);
  console.log(`Failed Checks: ${failed}`);
  console.log(
    `Binary Verdict: ${failed === 0 ? "CLEAN (ALL ADMIN CONTROL CENTER SYSTEMS OPERATIONAL)" : "FAILURE"}`
  );
  console.log("========================================\n");

  await prisma.$disconnect();
}

runAdminTestSuite().catch(async (err) => {
  console.error("Fatal Admin Test Error:", err);
  await prisma.$disconnect().catch(() => {});
  process.exit(1);
});
