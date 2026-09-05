/**
 * Test Suite for Crypto Transport Obfuscation & Security
 * Validates AES-GCM-256 encryption, HMAC-SHA256 signatures, Base64URL entropy masking,
 * tampering detection, replay protection, SSE chunk encryption, and route-level
 * strict obfuscation enforcement on all sensitive endpoints.
 */

import { NextRequest } from "next/server";
import {
  encryptPayload,
  decryptPayload,
  signPayload,
  safeCompareHex,
  decryptAndVerifyRequest,
  createEncryptedResponse,
  encryptStreamChunk,
  decryptStreamChunk,
  ENC_KEY,
  HMAC_KEY,
} from "../lib/crypto-transport";

import { POST as aiSolvePost } from "../app/api/ai/solve/route";
import { POST as aiStreamPost } from "../app/api/ai/stream/route";
import { POST as historySyncPost } from "../app/api/history/sync/route";
import { POST as notesSyncPost } from "../app/api/notes/sync/route";
import { POST as authDevicePost } from "../app/api/auth/device/route";
import {
  POST as authDeviceVerifyPost,
  GET as authDeviceVerifyGet,
} from "../app/api/auth/device/verify/route";
import { POST as telemetryEventPost } from "../app/api/telemetry/event/route";
import { POST as telemetryCrashPost } from "../app/api/telemetry/crash/route";

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

function makeEncryptedRequest(url: string, payloadObj: any): NextRequest {
  const { payload, timestamp, nonce, signature } = encryptPayload(payloadObj);
  return new NextRequest(url, {
    method: "POST",
    headers: {
      "x-signature": signature,
      "x-timestamp": timestamp,
      "x-nonce": nonce,
      "content-type": "application/octet-stream",
    },
    body: payload,
  });
}

function makePlainRequest(url: string, payloadObj: any): NextRequest {
  return new NextRequest(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
    },
    body: JSON.stringify(payloadObj),
  });
}

async function runCryptoTransportSuite() {
  console.log("=== STARTING CRYPTO TRANSPORT VERIFICATION SUITE ===\n");

  // 1. Key Derivation Check
  console.log("--- Checking Derived Cryptographic Keys ---");
  assert(ENC_KEY.length === 32, "AES-256 encryption key is 32 bytes (256 bits)");
  assert(HMAC_KEY.length === 32, "HMAC-SHA256 signing key is 32 bytes (256 bits)");

  // 2. Encryption and Decryption Roundtrip
  console.log("\n--- Checking Encryption and Decryption Roundtrip ---");
  const testObject = {
    prompt: "Integrate x^3 * e^x dx",
    mode: "math",
    deviceId: "device-test-12345",
    nested: {
      tags: ["calculus", "integration-by-parts"],
      values: [1, 2, 3.14159],
    },
  };

  const { payload, timestamp, nonce, signature } = encryptPayload(testObject);
  assert(typeof payload === "string" && payload.length > 50, "Encrypted payload is Base64URL string");
  assert(!payload.includes("Integrate") && !payload.includes("calculus"), "Payload hides plaintext keywords");
  assert(!payload.includes("+") && !payload.includes("/") && !payload.includes("="), "Payload is valid Base64URL without padding");

  // Decrypt payload
  const decrypted = decryptPayload<typeof testObject>(payload);
  assert(decrypted.prompt === testObject.prompt, "Decrypted prompt matches original");
  assert(decrypted.nested.values[2] === 3.14159, "Decrypted nested data matches original");

  // 3. Ciphertext Randomization / Nonce Uniqueness
  console.log("\n--- Checking Ciphertext Randomization (IV uniqueness) ---");
  const enc1 = encryptPayload("identical plaintext");
  const enc2 = encryptPayload("identical plaintext");
  assert(enc1.payload !== enc2.payload, "Identical plaintexts produce different ciphertexts (distinct IVs)");

  // 4. Dynamic HMAC-SHA256 Signature Verification
  console.log("\n--- Checking HMAC-SHA256 Dynamic Signatures ---");
  const expectedSig = signPayload(timestamp, nonce, payload);
  assert(signature === expectedSig, "Generated signature matches expected HMAC-SHA256 hex");
  assert(signature.length === 64, "Signature is 64 hex characters (32 bytes)");
  assert(safeCompareHex(signature, expectedSig), "safeCompareHex returns true for matching signatures");
  assert(!safeCompareHex(signature, "0".repeat(64)), "safeCompareHex returns false for non-matching signature");

  // 5. Request Verification Middleware - Valid Encrypted Request
  console.log("\n--- Checking decryptAndVerifyRequest on Valid Encrypted Request ---");
  const validReq = new Request("http://localhost/api/ai/solve", {
    method: "POST",
    headers: {
      "X-Signature": signature,
      "X-Timestamp": timestamp,
      "X-Nonce": nonce,
      "Content-Type": "application/octet-stream",
    },
    body: payload,
  });

  const validRes = await decryptAndVerifyRequest(validReq);
  assert(validRes.success === true, "Valid encrypted request passes verification");
  if (validRes.success) {
    assert(validRes.data.prompt === testObject.prompt, "Decrypted request data matches");
  }

  // 6. Rejection of Plaintext JSON Request
  console.log("\n--- Checking Rejection of Plaintext JSON Request ---");
  const plainReq = new Request("http://localhost/api/ai/solve", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(testObject),
  });

  const plainRes = await decryptAndVerifyRequest(plainReq);
  assert(plainRes.success === false, "Plaintext JSON request without headers rejected");
  if (!plainRes.success) {
    assert(plainRes.status === 403, "Plaintext JSON request returns HTTP 403 Forbidden");
  }

  // 7. Rejection of Request Missing Security Headers
  console.log("\n--- Checking Rejection of Missing Security Headers ---");
  const missingNonceReq = new Request("http://localhost/api/history/sync", {
    method: "POST",
    headers: {
      "X-Signature": signature,
      "X-Timestamp": timestamp,
      // Missing X-Nonce
    },
    body: payload,
  });
  const missingNonceRes = await decryptAndVerifyRequest(missingNonceReq);
  assert(missingNonceRes.success === false, "Missing X-Nonce header rejected");
  if (!missingNonceRes.success) {
    assert(missingNonceRes.status === 403, "Missing X-Nonce header rejected with 403");
  }

  // 8. Rejection of Expired Timestamp (Replay Attack Prevention)
  console.log("\n--- Checking Expired Timestamp Rejection ---");
  const expiredTimestamp = Math.floor(Date.now() / 1000 - 400).toString(); // 400s ago (> 300s window)
  const expiredSig = signPayload(expiredTimestamp, nonce, payload);
  const expiredReq = new Request("http://localhost/api/history/sync", {
    method: "POST",
    headers: {
      "X-Signature": expiredSig,
      "X-Timestamp": expiredTimestamp,
      "X-Nonce": nonce,
    },
    body: payload,
  });
  const expiredRes = await decryptAndVerifyRequest(expiredReq);
  assert(expiredRes.success === false, "Expired timestamp rejected");
  if (!expiredRes.success) {
    assert(expiredRes.status === 403, "Expired timestamp rejected with 403");
  }

  // 9. Rejection of Tampered Ciphertext (Payload Integrity / Authentication Tag)
  console.log("\n--- Checking Tampered Ciphertext Rejection ---");
  // Flip one character in the payload
  const tamperedPayload =
    payload.slice(0, 10) + (payload[10] === "a" ? "b" : "a") + payload.slice(11);
  const tamperedReq = new Request("http://localhost/api/ai/solve", {
    method: "POST",
    headers: {
      "X-Signature": signature, // Signature was for original payload
      "X-Timestamp": timestamp,
      "X-Nonce": nonce,
    },
    body: tamperedPayload,
  });
  const tamperedRes = await decryptAndVerifyRequest(tamperedReq);
  assert(tamperedRes.success === false, "Tampered payload fails signature verification");
  if (!tamperedRes.success) {
    assert(tamperedRes.status === 403, "Tampered payload returns 403");
  }

  // Tampered payload with valid signature for the tampered text (GCM auth tag check)
  const tamperedSig = signPayload(timestamp, nonce, tamperedPayload);
  const tamperedPayloadWithSigReq = new Request("http://localhost/api/ai/solve", {
    method: "POST",
    headers: {
      "X-Signature": tamperedSig,
      "X-Timestamp": timestamp,
      "X-Nonce": nonce,
    },
    body: tamperedPayload,
  });
  const tamperedAuthRes = await decryptAndVerifyRequest(tamperedPayloadWithSigReq);
  assert(tamperedAuthRes.success === false, "Tampered ciphertext fails AES-GCM tag verification");
  if (!tamperedAuthRes.success) {
    assert(tamperedAuthRes.status === 403, "Tampered ciphertext returns 403");
  }

  // 10. Encrypted Response Factory Check
  console.log("\n--- Checking Encrypted Response Creation ---");
  const encResponse = createEncryptedResponse({ status: "success", count: 42 }, 201);
  assert(encResponse.status === 201, "Encrypted response retains HTTP status");
  assert(encResponse.headers.get("Content-Type")?.includes("application/octet-stream") === true, "Response Content-Type is application/octet-stream");
  assert(Boolean(encResponse.headers.get("X-Signature")), "Response includes X-Signature header");
  assert(Boolean(encResponse.headers.get("X-Timestamp")), "Response includes X-Timestamp header");
  assert(Boolean(encResponse.headers.get("X-Nonce")), "Response includes X-Nonce header");
  assert(encResponse.headers.get("X-Encrypted") === "1", "Response includes X-Encrypted header");

  const encResponseBody = await encResponse.text();
  const decryptedResponse = decryptPayload(encResponseBody);
  assert(decryptedResponse.status === "success" && decryptedResponse.count === 42, "Decrypted response matches original payload");

  // 11. SSE Streaming Chunk Encryption & Decryption
  console.log("\n--- Checking SSE Streaming Chunk Encryption ---");
  const chunkText = "The integral evaluates to e^x * (x^3 - 3x^2 + 6x - 6) + C";
  const encChunk = encryptStreamChunk(chunkText, false);
  assert(!encChunk.includes("integral"), "SSE chunk is fully obfuscated");
  const decChunk = decryptStreamChunk(encChunk);
  assert(decChunk.text === chunkText, "Decrypted SSE chunk text matches");
  assert(decChunk.done === false, "Decrypted SSE chunk done flag is false");

  const doneChunk = encryptStreamChunk("", true);
  const decDone = decryptStreamChunk(doneChunk);
  assert(decDone.done === true, "Decrypted SSE chunk done flag is true");

  // =========================================================================
  // 12. ROUTE HANDLER TESTS (STRICT OBFUSCATION ENFORCEMENT & EXECUTION)
  // =========================================================================
  console.log("\n--- Checking Route Handler Strict Enforcement on Sensitive Endpoints ---");

  // Endpoint: /api/ai/solve
  console.log("Testing /api/ai/solve...");
  const solvePlainRes = await aiSolvePost(makePlainRequest("http://localhost/api/ai/solve", { expression: "2 + 2" }));
  assert(solvePlainRes.status === 403, "/api/ai/solve rejects plain JSON with 403");

  const solveEncReq = makeEncryptedRequest("http://localhost/api/ai/solve", { expression: "12 * 12", mode: "math" });
  const solveEncRes = await aiSolvePost(solveEncReq);
  assert(solveEncRes.status === 200, "/api/ai/solve accepts encrypted request with 200");
  assert(solveEncRes.headers.get("X-Encrypted") === "1", "/api/ai/solve returns X-Encrypted header");
  const solveBody = decryptPayload(await solveEncRes.text());
  assert(solveBody.success === true, "/api/ai/solve decrypted response indicates success");

  // Endpoint: /api/ai/stream
  console.log("Testing /api/ai/stream...");
  const streamPlainRes = await aiStreamPost(makePlainRequest("http://localhost/api/ai/stream", { prompt: "Explain Euler formula" }));
  assert(streamPlainRes.status === 403, "/api/ai/stream rejects plain JSON with 403");

  const streamEncReq = makeEncryptedRequest("http://localhost/api/ai/stream", { prompt: "Explain Euler formula" });
  const streamEncRes = await aiStreamPost(streamEncReq);
  assert(streamEncRes.status === 200, "/api/ai/stream accepts encrypted request with 200");
  assert(streamEncRes.headers.get("Content-Type")?.includes("text/event-stream") === true, "/api/ai/stream returns text/event-stream");
  assert(streamEncRes.headers.get("X-Encrypted") === "1", "/api/ai/stream returns X-Encrypted header");

  // Endpoint: /api/history/sync
  console.log("Testing /api/history/sync...");
  const histPlainRes = await historySyncPost(makePlainRequest("http://localhost/api/history/sync", { items: [] }));
  assert(histPlainRes.status === 403, "/api/history/sync rejects plain JSON with 403");

  const testHistItem = {
    id: "route-hist-test-01",
    timestamp: new Date().toISOString(),
    expression: "sqrt(16)",
    result: "4",
    mode: "scientific",
    deviceId: "device-test-01",
  };
  const histEncReq = makeEncryptedRequest("http://localhost/api/history/sync", {
    items: [testHistItem],
    deviceId: "device-test-01",
  });
  const histEncRes = await historySyncPost(histEncReq);
  assert(histEncRes.status === 200, "/api/history/sync accepts encrypted request with 200");
  const histBody = decryptPayload(await histEncRes.text());
  assert(histBody.success === true, "/api/history/sync decrypted response reports success");

  // Endpoint: /api/notes/sync
  console.log("Testing /api/notes/sync...");
  const notePlainRes = await notesSyncPost(makePlainRequest("http://localhost/api/notes/sync", { notes: [] }));
  assert(notePlainRes.status === 403, "/api/notes/sync rejects plain JSON with 403");

  const testNoteItem = {
    id: "route-note-test-01",
    title: "Calculus Derivatives",
    markdown: "d/dx(sin(x)) = cos(x)",
    tags: ["calculus"],
    attachments: [],
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    deviceId: "device-test-01",
  };
  const noteEncReq = makeEncryptedRequest("http://localhost/api/notes/sync", {
    notes: [testNoteItem],
    deviceId: "device-test-01",
  });
  const noteEncRes = await notesSyncPost(noteEncReq);
  assert(noteEncRes.status === 200, "/api/notes/sync accepts encrypted request with 200");
  const noteBody = decryptPayload(await noteEncRes.text());
  assert(noteBody.success === true, "/api/notes/sync decrypted response reports success");

  // Endpoint: /api/auth/device
  console.log("Testing /api/auth/device...");
  const devPlainRes = await authDevicePost(makePlainRequest("http://localhost/api/auth/device", { platform: "ios" }));
  assert(devPlainRes.status === 403, "/api/auth/device rejects plain JSON with 403");

  const devEncReq = makeEncryptedRequest("http://localhost/api/auth/device", {
    deviceId: "ios-unit-test-device-01",
    platform: "ios",
    name: "Test iPhone 16 Pro",
  });
  const devEncRes = await authDevicePost(devEncReq);
  assert(devEncRes.status === 200, "/api/auth/device accepts encrypted request with 200");
  const devBody = decryptPayload(await devEncRes.text());
  assert(devBody.success === true && typeof devBody.deviceToken === "string", "/api/auth/device issued device token");
  const issuedToken = devBody.deviceToken;

  // Endpoint: /api/auth/device/verify (POST)
  console.log("Testing /api/auth/device/verify (POST)...");
  const verifyPlainRes = await authDeviceVerifyPost(makePlainRequest("http://localhost/api/auth/device/verify", { token: issuedToken }));
  assert(verifyPlainRes.status === 403, "/api/auth/device/verify rejects plain JSON with 403");

  const verifyEncReq = makeEncryptedRequest("http://localhost/api/auth/device/verify", { token: issuedToken });
  const verifyEncRes = await authDeviceVerifyPost(verifyEncReq);
  assert(verifyEncRes.status === 200, "/api/auth/device/verify accepts encrypted request with 200");
  const verifyBody = decryptPayload(await verifyEncRes.text());
  assert(verifyBody.valid === true, "/api/auth/device/verify verified issued device token");

  // Endpoint: /api/auth/device/verify (GET)
  console.log("Testing /api/auth/device/verify (GET)...");
  const getPlainReq = new NextRequest("http://localhost/api/auth/device/verify?token=" + issuedToken);
  const getPlainRes = await authDeviceVerifyGet(getPlainReq);
  assert(getPlainRes.status === 403, "/api/auth/device/verify (GET) rejects request without signatures with 403");

  const ts = Math.floor(Date.now() / 1000).toString();
  const nnc = "abcdef1234567890abcdef1234567890";
  const getSig = signPayload(ts, nnc, "");
  const getEncReq = new NextRequest(`http://localhost/api/auth/device/verify?token=${issuedToken}`, {
    method: "GET",
    headers: {
      "x-signature": getSig,
      "x-timestamp": ts,
      "x-nonce": nnc,
    },
  });
  const getEncRes = await authDeviceVerifyGet(getEncReq);
  assert(getEncRes.status === 200, "/api/auth/device/verify (GET) accepts signed request with 200");
  const getVerifyBody = decryptPayload(await getEncRes.text());
  assert(getVerifyBody.valid === true, "/api/auth/device/verify (GET) verified token");

  // Endpoint: /api/telemetry/event
  console.log("Testing /api/telemetry/event...");
  const telemPlainRes = await telemetryEventPost(makePlainRequest("http://localhost/api/telemetry/event", { name: "test_event" }));
  assert(telemPlainRes.status === 403, "/api/telemetry/event rejects plain JSON with 403");

  const telemEncReq = makeEncryptedRequest("http://localhost/api/telemetry/event", {
    name: "calculation_completed",
    type: "calculation",
    deviceId: "device-test-01",
    payload: { expression: "2+2", latencyMs: 12 },
  });
  const telemEncRes = await telemetryEventPost(telemEncReq);
  assert(telemEncRes.status === 201, "/api/telemetry/event accepts encrypted request with 201");
  const telemBody = decryptPayload(await telemEncRes.text());
  assert(telemBody.success === true && telemBody.eventId, "/api/telemetry/event recorded event");

  // Endpoint: /api/telemetry/crash
  console.log("Testing /api/telemetry/crash...");
  const crashPlainRes = await telemetryCrashPost(makePlainRequest("http://localhost/api/telemetry/crash", { error: "fatal error" }));
  assert(crashPlainRes.status === 403, "/api/telemetry/crash rejects plain JSON with 403");

  const crashEncReq = makeEncryptedRequest("http://localhost/api/telemetry/crash", {
    error: "IndexOutOfBoundsException",
    stackTrace: "at Array.get()",
    deviceId: "device-test-01",
    breadcrumbs: ["opened app", "typed 55"],
  });
  const crashEncRes = await telemetryCrashPost(crashEncReq);
  assert(crashEncRes.status === 201, "/api/telemetry/crash accepts encrypted request with 201");
  const crashBody = decryptPayload(await crashEncRes.text());
  assert(crashBody.success === true && crashBody.eventId, "/api/telemetry/crash recorded crash");

  console.log(`\n========================================`);
  console.log(`CRYPTO TRANSPORT SUMMARY:`);
  console.log(`Passed Checks: ${passed}`);
  console.log(`Failed Checks: ${failed}`);
  console.log(`Binary Verdict: ${failed === 0 ? "CLEAN (ALL CRYPTO AND ROUTE ENFORCEMENT TESTS 100% PASSED)" : "FAILURE"}`);
  console.log(`========================================\n`);
}

runCryptoTransportSuite().catch((err) => {
  console.error("Fatal Crypto Transport Error:", err);
  process.exit(1);
});
