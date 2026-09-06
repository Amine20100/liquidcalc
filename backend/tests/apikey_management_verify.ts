import { GET as getApiKey, POST as saveApiKey, DELETE as deleteApiKey } from "../app/api/admin/apikey/route";
import { POST as testApiKey } from "../app/api/admin/apikey/test/route";
import { NextRequest } from "next/server";
import { getPersistedGeminiApiKey } from "../lib/gemini-key-store";

async function runApiKeyManagementVerify() {
  console.log("=== STARTING DYNAMIC GEMINI API KEY MANAGEMENT VERIFICATION ===");
  const adminSecret = process.env.ADMIN_SECRET_KEY || "lqc_admin_secret_super_key_2026";
  let passed = 0;
  let failed = 0;

  function assert(condition: boolean, desc: string) {
    if (condition) {
      console.log(`✅ PASS: ${desc}`);
      passed++;
    } else {
      console.error(`❌ FAIL: ${desc}`);
      failed++;
    }
  }

  // 1. Security & Authentication Checks
  const unauthReq = new NextRequest("http://localhost/api/admin/apikey");
  const unauthRes = await getApiKey(unauthReq);
  assert(unauthRes.status === 401, "Unauthenticated GET /api/admin/apikey rejected with 401");

  // 2. GET /api/admin/apikey with Admin Key
  const authedReq = new NextRequest("http://localhost/api/admin/apikey", {
    headers: { "x-admin-key": adminSecret },
  });
  const authedRes = await getApiKey(authedReq);
  assert(authedRes.status === 200, "Authenticated GET /api/admin/apikey returns 200 OK");
  const initialData = await authedRes.json();
  assert(initialData.success === true, "GET returns success: true");
  assert(typeof initialData.maskedKey === "string", "GET returns maskedKey string");

  // 3. POST /api/admin/apikey to set a test key
  const mockKey = "AIzaSyMockKeyForAutomatedTesting9999";
  const postReq = new NextRequest("http://localhost/api/admin/apikey", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-admin-key": adminSecret,
    },
    body: JSON.stringify({ apiKey: mockKey }),
  });
  const postRes = await saveApiKey(postReq);
  assert(postRes.status === 200, "POST /api/admin/apikey returns 200 OK");
  const postData = await postRes.json();
  assert(postData.success === true, "POST returns success: true");
  assert(postData.maskedKey.startsWith("AIzaSy"), "POST returns masked key starting with AIzaSy");

  // 4. Verify persisted key retrieval
  const resolved = await getPersistedGeminiApiKey();
  assert(resolved === mockKey, "Resolved persisted key matches saved key");

  // 5. Test Key Validation (POST /api/admin/apikey/test)
  const testReq = new NextRequest("http://localhost/api/admin/apikey/test", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-admin-key": adminSecret,
    },
    body: JSON.stringify({ apiKey: mockKey }),
  });
  const testRes = await testApiKey(testReq);
  assert(testRes.status === 200, "POST /api/admin/apikey/test returns 200 OK (even if mock key returns Google 400 error)");
  const testData = await testRes.json();
  assert(typeof testData.latencyMs === "number", "Test key route returns latencyMs");

  // 6. Clean up: DELETE /api/admin/apikey
  const deleteReq = new NextRequest("http://localhost/api/admin/apikey", {
    method: "DELETE",
    headers: { "x-admin-key": adminSecret },
  });
  const deleteRes = await deleteApiKey(deleteReq);
  assert(deleteRes.status === 200, "DELETE /api/admin/apikey returns 200 OK");
  const deleteData = await deleteRes.json();
  assert(deleteData.hasKey === false, "DELETE reports hasKey: false");

  console.log(`\n========================================`);
  console.log(`Passed: ${passed}, Failed: ${failed}`);
  if (failed > 0) {
    process.exit(1);
  }
}

runApiKeyManagementVerify().catch((err) => {
  console.error("Test execution failed:", err);
  process.exit(1);
});
