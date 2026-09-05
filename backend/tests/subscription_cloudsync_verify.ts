/**
 * Subscription, Paid Plans, Guest Account Linking & Cloud Sync Quota Verification Suite
 * Tests:
 * 1. Public Plans & Tier Entitlements (GET /api/plans)
 * 2. Subscription Creation & Mock Checkout (POST /api/subscription/create)
 * 3. Receipt Verification for Mock, Apple StoreKit & Stripe (POST /api/subscription/verify)
 * 4. Subscription Status & Real-time Entitlement Limits (GET /api/subscription/status)
 * 5. Promo Code Redemption & Tier Activation (POST /api/subscription/promo)
 * 6. Guest Mode & Anonymous-to-Account Linking without Data Loss (POST /api/auth/link-account)
 * 7. Cloud Sync Quota Enforcement (Free 50 items limit vs Pro/Ultra unlimited)
 * 8. Payment Webhook Ingestion (Stripe & Apple StoreKit)
 */

import { prisma } from "../lib/prisma";
import { historyStore } from "../lib/storage";
import { notesStore } from "../lib/notes";
import { hashPassword, signAccessToken } from "../lib/auth";
import {
  getUserOrDeviceSubscription,
  createSubscription,
  verifySubscriptionReceipt,
  redeemPromoCode,
  linkGuestAccount,
  checkCloudSyncQuota,
  getTierLimits,
} from "../lib/subscription";
import { GET as getPlansRoute } from "../app/api/plans/route";
import { POST as createSubRoute } from "../app/api/subscription/create/route";
import { POST as verifySubRoute } from "../app/api/subscription/verify/route";
import { GET as statusSubRoute } from "../app/api/subscription/status/route";
import { POST as promoSubRoute } from "../app/api/subscription/promo/route";
import { POST as linkAccountRoute } from "../app/api/auth/link-account/route";
import { POST as stripeWebhookRoute } from "../app/api/webhooks/stripe/route";
import { POST as appleWebhookRoute } from "../app/api/webhooks/apple/route";
import { GET as historyRouteGet, POST as historyRoutePost } from "../app/api/history/route";
import { GET as notesRouteGet, POST as notesRoutePost } from "../app/api/notes/route";
import { issueDeviceToken, authenticateRequest } from "../lib/auth";
import { encryptPayload, decryptPayload } from "../lib/crypto-transport";

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

function makeJsonRequest(
  url: string,
  body: any,
  headers: Record<string, string> = {}
): any {
  return new Request(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...headers,
    },
    body: JSON.stringify(body),
  });
}

function makeGetRequest(
  url: string,
  headers: Record<string, string> = {}
): any {
  const req = new Request(url, {
    method: "GET",
    headers: {
      ...headers,
    },
  });
  // NextRequest simulation for nextUrl
  (req as any).nextUrl = new URL(url);
  return req;
}

async function runSubscriptionTestSuite() {
  console.log("=== STARTING SUBSCRIPTION, GUEST LINKING & CLOUD SYNC SUITE ===\n");

  // TEST 1: Plans & Feature Tiers
  console.log("--- 1. Testing Public Plans & Tiers Matrix (GET /api/plans) ---");
  const plansReq = makeGetRequest("http://localhost/api/plans");
  const plansRes = await getPlansRoute(plansReq);
  assert(plansRes.status === 200, "/api/plans returns HTTP 200");
  const plansData = await plansRes.json();
  assert(plansData.success === true, "Plans endpoint returns success: true");
  assert(Array.isArray(plansData.plans), "Plans is an array");
  assert(plansData.plans.length >= 3, "Plans contains at least 3 plans (Free, Pro, Ultra)");
  assert(
    plansData.plans.some((p: any) => p.tier === "FREE"),
    "Plans includes FREE tier"
  );
  assert(
    plansData.plans.some((p: any) => p.tier === "PRO"),
    "Plans includes PRO tier"
  );
  assert(
    plansData.plans.some((p: any) => p.tier === "ULTRA"),
    "Plans includes ULTRA tier"
  );
  assert(
    plansData.tierEntitlements.FREE.maxCloudSyncItems === 50,
    "Free tier sync limit is 50 items"
  );
  assert(
    plansData.tierEntitlements.PRO.maxCloudSyncItems === -1,
    "Pro tier sync limit is unlimited (-1)"
  );
  assert(
    plansData.tierEntitlements.ULTRA.priorityAi === true,
    "Ultra tier includes priority AI solver"
  );
  assert(
    Array.isArray(plansData.comparison) && plansData.comparison.length > 0,
    "Feature comparison matrix returned"
  );

  // TEST 2: Subscription Creation via API
  console.log("\n--- 2. Testing Subscription Creation (POST /api/subscription/create) ---");
  const testUser1 = await prisma.user.create({
    data: {
      email: `sub_tester_${Date.now()}@liquidcalc.local`,
      passwordHash: await hashPassword("SubSecret2026!"),
      name: "Subscription Tester",
      role: "user",
    },
  });

  const user1Token = await signAccessToken({
    sub: testUser1.id,
    email: testUser1.email,
    role: testUser1.role,
    type: "user",
  });

  const createReq = makeJsonRequest(
    "http://localhost/api/subscription/create",
    {
      tier: "PRO",
      billingPeriod: "monthly",
      provider: "mock",
    },
    { authorization: `Bearer ${user1Token}` }
  );

  const createRes = await createSubRoute(createReq);
  assert(createRes.status === 201, "Create subscription returns 201 Created");
  const createData = await createRes.json();
  assert(createData.success === true, "Subscription creation returns success: true");
  assert(createData.subscription.tier === "PRO", "Created subscription tier is PRO");
  assert(createData.subscription.userId === testUser1.id, "Subscription linked to user");
  assert(createData.entitlements.canOtaSign === true, "Pro entitlements allow OTA signing");

  // TEST 3: Receipt Verification (Mock, Apple StoreKit, Stripe)
  console.log("\n--- 3. Testing Receipt Verification (POST /api/subscription/verify) ---");
  const guestDeviceId = `iPhone16,2_Guest_${Date.now()}`;

  // Mock Receipt for ULTRA tier
  const verifyMockReq = makeJsonRequest(
    "http://localhost/api/subscription/verify",
    {
      receipt: "mock_receipt_ultra_yearly_test",
      tier: "ULTRA",
      deviceId: guestDeviceId,
    }
  );
  const verifyMockRes = await verifySubRoute(verifyMockReq);
  assert(verifyMockRes.status === 200, "Verify mock receipt returns 200 OK");
  const verifyMockData = await verifyMockRes.json();
  assert(verifyMockData.valid === true, "Mock receipt marked valid");
  assert(verifyMockData.tier === "ULTRA", "Ultra tier granted from mock receipt");
  assert(verifyMockData.entitlements.priorityAi === true, "Ultra includes priority AI");

  // Apple StoreKit Base64 Receipt
  const fakeStoreKitPayload = Buffer.from(
    JSON.stringify({
      bundleId: "com.liquidcalc.ios",
      productId: "com.liquidcalc.pro.annual",
      originalTransactionId: `storekit_tx_${Date.now()}`,
    })
  ).toString("base64");

  const verifyAppleReq = makeJsonRequest(
    "http://localhost/api/subscription/verify",
    {
      receipt: fakeStoreKitPayload,
      provider: "apple_storekit",
      deviceId: guestDeviceId,
    }
  );
  const verifyAppleRes = await verifySubRoute(verifyAppleReq);
  assert(verifyAppleRes.status === 200, "Verify Apple StoreKit receipt returns 200");
  const verifyAppleData = await verifyAppleRes.json();
  assert(verifyAppleData.valid === true, "Apple StoreKit receipt validated");

  // Stripe Session verification
  const verifyStripeReq = makeJsonRequest(
    "http://localhost/api/subscription/verify",
    {
      receipt: `cs_test_${Date.now()}`,
      provider: "stripe",
      tier: "PRO",
      userId: testUser1.id,
    }
  );
  const verifyStripeRes = await verifySubRoute(verifyStripeReq);
  assert(verifyStripeRes.status === 200, "Verify Stripe session returns 200");

  // Reject empty receipt
  const badVerifyReq = makeJsonRequest("http://localhost/api/subscription/verify", {
    receipt: "",
  });
  const badVerifyRes = await verifySubRoute(badVerifyReq);
  assert(badVerifyRes.status === 400, "Empty receipt rejected with 400 Bad Request");

  // TEST 4: Subscription Status & Entitlement Query (GET /api/subscription/status)
  console.log("\n--- 4. Testing Subscription Status (GET /api/subscription/status) ---");
  const userStatusReq = makeGetRequest(
    `http://localhost/api/subscription/status?userId=${testUser1.id}`
  );
  const userStatusRes = await statusSubRoute(userStatusReq);
  assert(userStatusRes.status === 200, "/api/subscription/status returns 200");
  const userStatusData = await userStatusRes.json();
  assert(userStatusData.success === true, "Status query returns success");
  assert(userStatusData.tier === "PRO", "User active tier is PRO");
  assert(userStatusData.cloudSyncUsage.isUnlimited === true, "Pro user cloud sync is unlimited");

  // Unregistered device status (defaults to FREE)
  const freshDeviceId = `fresh_guest_dev_${Date.now()}`;
  const freeStatusReq = makeGetRequest(
    `http://localhost/api/subscription/status?deviceId=${freshDeviceId}`
  );
  const freeStatusRes = await statusSubRoute(freeStatusReq);
  const freeStatusData = await freeStatusRes.json();
  assert(freeStatusData.tier === "FREE", "Unregistered device defaults to FREE tier");
  assert(freeStatusData.cloudSyncUsage.maxAllowedItems === 50, "Free tier sync quota is 50 items");
  assert(freeStatusData.cloudSyncUsage.isUnlimited === false, "Free tier is not unlimited");

  // TEST 5: Promo Code Redemption (POST /api/subscription/promo)
  console.log("\n--- 5. Testing Promo Code Redemption (POST /api/subscription/promo) ---");
  const promoDevId = `promo_dev_${Date.now()}`;
  const promoReq = makeJsonRequest("http://localhost/api/subscription/promo", {
    code: "PROMO_ULTRA_VIP",
    deviceId: promoDevId,
  });
  const promoRes = await promoSubRoute(promoReq);
  assert(promoRes.status === 200, "Valid promo code returns 200");
  const promoData = await promoRes.json();
  assert(promoData.success === true, "Promo code redeemed successfully");
  assert(promoData.tier === "ULTRA", "ULTRA tier granted by PROMO_ULTRA_VIP");
  assert(promoData.durationDays === 90, "90 days duration applied");

  // Reject invalid promo code
  const invalidPromoReq = makeJsonRequest("http://localhost/api/subscription/promo", {
    code: "INVALID_FAKE_CODE_999",
    deviceId: promoDevId,
  });
  const invalidPromoRes = await promoSubRoute(invalidPromoReq);
  assert(invalidPromoRes.status === 400, "Invalid promo code rejected with 400");

  // TEST 6: Enhanced Auth & Guest Linking Flow (POST /api/auth/link-account)
  console.log("\n--- 6. Testing Guest Account Linking Flow (POST /api/auth/link-account) ---");
  const guestId = `guest_device_session_${Date.now()}`;

  // 1. Create guest calculation items
  const guestCalc1Id = `calc_guest_1_${Date.now()}`;
  const guestCalc2Id = `calc_guest_2_${Date.now()}`;
  historyStore.sync(
    [
      {
        id: guestCalc1Id,
        expression: "sin(pi / 4)^2 + cos(pi / 4)^2",
        result: "1",
        mode: "scientific",
        notes: "Trigonometric identity",
        deviceId: guestId,
        timestamp: new Date().toISOString(),
      },
      {
        id: guestCalc2Id,
        expression: "1000 * (1 + 0.05)^3",
        result: "1157.625",
        mode: "financial",
        notes: "Compound interest",
        deviceId: guestId,
        timestamp: new Date().toISOString(),
      },
    ],
    guestId
  );

  // 2. Create guest notes
  const guestNote1Id = `note_guest_1_${Date.now()}`;
  await notesStore.sync(
    [
      {
        id: guestNote1Id,
        title: "Guest Physics Notes",
        markdown: "# Kinematics\n\n$$v = v_0 + at$$\n$$x = x_0 + v_0 t + \\frac{1}{2}at^2$$",
        tags: ["physics", "kinematics"],
        attachments: [],
        deviceId: guestId,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
    ],
    guestId
  );

  // 3. Guest redeems promo code on this device
  await redeemPromoCode({ code: "PROMO_PRO_2026", deviceId: guestId });

  // 4. Guest links device to new registered account via /api/auth/link-account
  const linkEmail = `linked_user_${Date.now()}@liquidcalc.local`;
  const linkPassword = "PasswordLink2026!";
  const linkReq = makeJsonRequest("http://localhost/api/auth/link-account", {
    deviceId: guestId,
    email: linkEmail,
    password: linkPassword,
    name: "Linked Power User",
  });

  const linkRes = await linkAccountRoute(linkReq);
  assert(linkRes.status === 200, "link-account returns 200 OK");
  const linkData = await linkRes.json();
  assert(linkData.success === true, "Guest linking reports success: true");
  assert(linkData.user.email === linkEmail, "User account created with email");
  assert(linkData.migrated.calculations >= 2, "At least 2 calculations migrated");
  assert(linkData.migrated.notes >= 1, "At least 1 note migrated");
  assert(linkData.tokens.accessToken.length > 20, "JWT accessToken issued for linked account");

  // 5. Verify calculations are now owned by the user in historyStore & database
  const migratedCalc = historyStore.get(guestCalc1Id);
  assert(migratedCalc !== null && migratedCalc.userId === linkData.user.id, "Calculation reassigned to linked user");
  const migratedNote = notesStore.get(guestNote1Id);
  assert(migratedNote !== null && migratedNote.userId === linkData.user.id, "Note reassigned to linked user");

  // 6. Test linking another device to existing user
  const secondDevId = `second_device_${Date.now()}`;
  historyStore.sync(
    [
      {
        id: `calc_dev2_${Date.now()}`,
        expression: "log10(1000)",
        result: "3",
        mode: "standard",
        deviceId: secondDevId,
        timestamp: new Date().toISOString(),
      },
    ],
    secondDevId
  );

  const linkSecondReq = makeJsonRequest(
    "http://localhost/api/auth/link-account",
    {
      deviceId: secondDevId,
      email: linkEmail,
      password: linkPassword,
    }
  );
  const linkSecondRes = await linkAccountRoute(linkSecondReq);
  assert(linkSecondRes.status === 200, "Second device linked to existing user account");
  const linkSecondData = await linkSecondRes.json();
  assert(linkSecondData.user.id === linkData.user.id, "Linked to same existing user account");

  // TEST 7: Cloud Sync Quota Enforcement
  console.log("\n--- 7. Testing Cloud Sync Quota Enforcement (Free vs Pro/Ultra) ---");
  const freeQuotaDeviceId = `free_quota_dev_${Date.now()}`;

  // Fill Free quota with 50 items
  for (let i = 0; i < 50; i++) {
    const item = {
      id: `quota_calc_${freeQuotaDeviceId}_${i}`,
      expression: `${i} + 1`,
      result: `${i + 1}`,
      mode: "standard",
      deviceId: freeQuotaDeviceId,
      timestamp: new Date().toISOString(),
      deleted: false,
    };
    historyStore.sync([item], freeQuotaDeviceId);
  }

  // Attempt to add 51st item via POST /api/history
  const exceedReq = makeJsonRequest("http://localhost/api/history", {
    expression: "51 + 1",
    result: "52",
    mode: "standard",
    deviceId: freeQuotaDeviceId,
  });
  const exceedRes = await historyRoutePost(exceedReq);
  assert(exceedRes.status === 403, "51st item rejected with 403 on Free tier quota");
  const exceedData = await exceedRes.json();
  assert(exceedData.code === "SYNC_QUOTA_EXCEEDED", "Error code is SYNC_QUOTA_EXCEEDED");
  assert(exceedData.upgradeRequired === true, "Upgrade prompt included in quota error");

  // Now upgrade device to PRO via promo code
  const upgradePromo = await redeemPromoCode({
    code: "PROMO_PRO_2026",
    deviceId: freeQuotaDeviceId,
  });
  assert(upgradePromo.success === true, "Device upgraded to PRO");

  // Try adding 51st item again after upgrade
  const postUpgradeReq = makeJsonRequest("http://localhost/api/history", {
    expression: "51 + 1",
    result: "52",
    mode: "standard",
    deviceId: freeQuotaDeviceId,
  });
  const postUpgradeRes = await historyRoutePost(postUpgradeReq);
  assert(postUpgradeRes.status === 201, "51st item accepted with 201 after upgrading to PRO");

  // TEST 8: Webhook Handlers (Stripe & Apple StoreKit)
  console.log("\n--- 8. Testing Webhook Handlers (Stripe & Apple StoreKit) ---");
  // Stripe Webhook: checkout.session.completed
  const stripeEvent = {
    id: `evt_test_${Date.now()}`,
    type: "checkout.session.completed",
    data: {
      object: {
        id: `cs_webhook_${Date.now()}`,
        customer_email: testUser1.email,
        amount_total: 7999, // $79.99 (ULTRA Yearly)
        subscription: `sub_stripe_${Date.now()}`,
      },
    },
  };
  const stripeReq = new Request("http://localhost/api/webhooks/stripe", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(stripeEvent),
  });
  const stripeRes = await stripeWebhookRoute(stripeReq);
  assert(stripeRes.status === 200, "Stripe webhook returns 200 OK");
  const stripeData = await stripeRes.json();
  assert(stripeData.received === true, "Stripe webhook received: true");

  // Apple StoreKit Webhook: DID_RENEW
  const appleNotification = {
    notificationType: "DID_RENEW",
    notificationUUID: `apple_uuid_${Date.now()}`,
    data: {
      bundleId: "com.liquidcalc.ios",
      originalTransactionId: `orig_tx_${Date.now()}`,
    },
  };
  const appleReq = new Request("http://localhost/api/webhooks/apple", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(appleNotification),
  });
  const appleRes = await appleWebhookRoute(appleReq);
  assert(appleRes.status === 200, "Apple webhook returns 200 OK");
  const appleData = await appleRes.json();
  assert(appleData.received === true, "Apple webhook received: true");

  // TEST 9: Advanced Concurrency, Lifecycle & Gateway Resilience
  console.log("\n--- 9. Advanced Concurrency, Lifecycle & Gateway Resilience ---");

  // 9.1 Multi-device guest linking race condition (2 distinct devices linking to the same brand new email simultaneously)
  const raceEmail = `race_user_${Date.now()}@liquidcalc.local`;
  const racePassword = "RacePassword2026!";
  const raceDev1 = `race_dev_1_${Date.now()}`;
  const raceDev2 = `race_dev_2_${Date.now()}`;

  historyStore.sync(
    [{ id: `calc_${raceDev1}`, expression: "2 + 2", result: "4", mode: "standard", deviceId: raceDev1, timestamp: new Date().toISOString() }],
    raceDev1
  );
  historyStore.sync(
    [{ id: `calc_${raceDev2}`, expression: "3 * 3", result: "9", mode: "standard", deviceId: raceDev2, timestamp: new Date().toISOString() }],
    raceDev2
  );

  const [raceRes1, raceRes2] = await Promise.all([
    linkAccountRoute(makeJsonRequest("http://localhost/api/auth/link-account", {
      deviceId: raceDev1,
      email: raceEmail,
      password: racePassword,
      name: "Race Test User",
    })),
    linkAccountRoute(makeJsonRequest("http://localhost/api/auth/link-account", {
      deviceId: raceDev2,
      email: raceEmail,
      password: racePassword,
    })),
  ]);

  assert(raceRes1.status === 200, "Race link device 1 succeeds with 200 OK");
  assert(raceRes2.status === 200, "Race link device 2 succeeds with 200 OK despite concurrent registration");
  const raceData1 = await raceRes1.json();
  const raceData2 = await raceRes2.json();
  assert(raceData1.user.id === raceData2.user.id, "Both racing devices bound to identical user record");

  // 9.2 Entitlement consolidation: verify no duplicate Entitlement rows
  const userEntitlements = await prisma.entitlement.findMany({
    where: { userId: raceData1.user.id },
  });
  assert(userEntitlements.length === 1, "Entitlements consolidated to exactly 1 authoritative record per user");

  // 9.3 Promo code double redemption prevention
  const doublePromoDev = `double_promo_dev_${Date.now()}`;
  const firstPromoRes = await promoSubRoute(makeJsonRequest("http://localhost/api/subscription/promo", {
    code: "TEST_ULTRA",
    deviceId: doublePromoDev,
  }));
  assert(firstPromoRes.status === 200, "First promo redemption succeeds");

  const secondPromoRes = await promoSubRoute(makeJsonRequest("http://localhost/api/subscription/promo", {
    code: "TEST_ULTRA",
    deviceId: doublePromoDev,
  }));
  assert(secondPromoRes.status === 400, "Second promo redemption rejected with 400");
  const secondPromoData = await secondPromoRes.json();
  assert(secondPromoData.error.includes("already been redeemed"), "Promo rejection mentions prior redemption");

  // 9.4 StoreKit 2 JWS token verification
  const jwsHeader = Buffer.from(JSON.stringify({ alg: "ES256", typ: "JWT" })).toString("base64url");
  const jwsPayload = Buffer.from(JSON.stringify({
    productId: "com.liquidcalc.ultra.yearly",
    tier: "ULTRA",
    bundleId: "com.liquidcalc.ios",
    originalTransactionId: `apple_jws_tx_${Date.now()}`,
    expiresDate: Date.now() + 365 * 24 * 3600 * 1000,
  })).toString("base64url");
  const jwsSignature = "mock_es256_jws_signature_payload";
  const fakeJwsToken = `${jwsHeader}.${jwsPayload}.${jwsSignature}`;

  const jwsVerifyRes = await verifySubRoute(makeJsonRequest("http://localhost/api/subscription/verify", {
    receipt: fakeJwsToken,
    provider: "apple_storekit",
    deviceId: `jws_dev_${Date.now()}`,
  }));
  assert(jwsVerifyRes.status === 200, "Apple StoreKit 2 JWS token receipt verified");
  const jwsVerifyData = await jwsVerifyRes.json();
  assert(jwsVerifyData.tier === "ULTRA", "Ultra tier decoded from StoreKit 2 JWS payload");

  // 9.5 Stripe cancellation webhook marks subscription canceled
  const stripeCancelSubId = `sub_stripe_cancel_${Date.now()}`;
  await prisma.subscription.create({
    data: {
      userId: testUser1.id,
      planId: "plan_pro_monthly",
      tier: "PRO",
      status: "active",
      provider: "stripe",
      providerSubId: stripeCancelSubId,
      currentPeriodStart: new Date(),
      currentPeriodEnd: new Date(Date.now() + 30 * 24 * 3600 * 1000),
    },
  });

  const cancelWebhookRes = await stripeWebhookRoute(new Request("http://localhost/api/webhooks/stripe", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      id: `evt_cancel_${Date.now()}`,
      type: "customer.subscription.deleted",
      data: { object: { id: stripeCancelSubId } },
    }),
  }));
  assert(cancelWebhookRes.status === 200, "Stripe cancellation webhook accepted");
  const canceledSub = await prisma.subscription.findFirst({
    where: { providerSubId: stripeCancelSubId },
  });
  assert(canceledSub?.status === "canceled", "Subscription status transitioned to canceled");

  // 9.6 Apple revoke webhook marks subscription expired
  const appleRevokeTxId = `apple_tx_revoke_${Date.now()}`;
  await prisma.subscription.create({
    data: {
      userId: testUser1.id,
      planId: "plan_pro_monthly",
      tier: "PRO",
      status: "active",
      provider: "apple_storekit",
      providerSubId: appleRevokeTxId,
      currentPeriodStart: new Date(),
      currentPeriodEnd: new Date(Date.now() + 30 * 24 * 3600 * 1000),
    },
  });

  const revokeWebhookRes = await appleWebhookRoute(new Request("http://localhost/api/webhooks/apple", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      notificationType: "REVOKE",
      notificationUUID: `apple_revoke_${Date.now()}`,
      data: { originalTransactionId: appleRevokeTxId },
    }),
  }));
  assert(revokeWebhookRes.status === 200, "Apple revoke webhook accepted");
  const revokedSub = await prisma.subscription.findFirst({
    where: { providerSubId: appleRevokeTxId },
  });
  assert(revokedSub?.status === "expired", "Apple subscription transitioned to expired");

  // 9.7 Scoped session querying on GET /api/history & GET /api/notes
  const scopedUserToken = await signAccessToken({
    sub: raceData1.user.id,
    email: raceData1.user.email,
    role: "user",
    type: "user",
  });

  const scopedHistoryRes = await historyRouteGet(makeGetRequest("http://localhost/api/history", {
    authorization: `Bearer ${scopedUserToken}`,
  }));
  assert(scopedHistoryRes.status === 200, "GET /api/history returns 200 for authenticated user");
  const scopedHistoryData = await scopedHistoryRes.json();
  assert(
    scopedHistoryData.items.every((i: any) => i.userId === raceData1.user.id),
    "Authenticated GET /api/history automatically scopes to user's calculations"
  );

  // 9.8 POST /api/history and POST /api/notes with device token resolves deviceId automatically
  const devTokenData = await issueDeviceToken({
    deviceId: `token_dev_${Date.now()}`,
    platform: "ios",
  });

  const expectedDeviceId = devTokenData.device?.deviceId || `token_dev_${Date.now()}`;
  const devHistoryRes = await historyRoutePost(makeJsonRequest("http://localhost/api/history", {
    expression: "42 * 2",
    result: "84",
  }, { "x-device-token": devTokenData.token }));
  assert(devHistoryRes.status === 201, "POST /api/history with device token succeeds with 201 Created");
  const devHistoryData = await devHistoryRes.json();
  assert(devHistoryData.item.deviceId === expectedDeviceId, "DeviceId correctly resolved from device token in history");

  const devNoteRes = await notesRoutePost(makeJsonRequest("http://localhost/api/notes", {
    title: "Device Token Note",
    markdown: "Testing device token auto-attribution",
  }, { "x-device-token": devTokenData.token }));
  assert(devNoteRes.status === 201, "POST /api/notes with device token succeeds with 201 Created");
  const devNoteData = await devNoteRes.json();
  assert(devNoteData.note.deviceId === expectedDeviceId, "DeviceId correctly resolved from device token in notes");

  // 9.9 Devices usage in GET /api/subscription/status
  const statusDevicesRes = await statusSubRoute(makeGetRequest(
    `http://localhost/api/subscription/status?userId=${raceData1.user.id}`
  ));
  assert(statusDevicesRes.status === 200, "Status query with devices returns 200");
  const statusDevicesData = await statusDevicesRes.json();
  assert(typeof statusDevicesData.devicesUsage === "object", "devicesUsage included in status");
  assert(statusDevicesData.devicesUsage.activeDevices >= 2, "Active devices correctly counted");
  assert(statusDevicesData.devicesUsage.maxDevices !== undefined, "maxDevices limit reported");

  // TEST 10: Encrypted Transport Pipeline & Auth Precedence
  console.log("\n--- 10. Testing Encrypted Transport Pipeline & Auth Precedence ---");

  function makeEncryptedReq(url: string, payloadObj: any, extraHeaders: Record<string, string> = {}): Request {
    const { payload, timestamp, nonce, signature } = encryptPayload(payloadObj);
    const headers = new Headers({
      "Content-Type": "application/octet-stream",
      "X-Signature": signature,
      "X-Timestamp": timestamp,
      "X-Nonce": nonce,
      ...extraHeaders,
    });
    return new Request(url, {
      method: "POST",
      headers,
      body: payload,
    });
  }

  // 10.1 Encrypted link-account
  const encGuestDeviceId = `enc_guest_${Date.now()}`;
  const encLinkReq = makeEncryptedReq("http://localhost/api/auth/link-account", {
    deviceId: encGuestDeviceId,
    email: `enc.guest.${Date.now()}@liquidcalc.test`,
    password: "Password123!",
    name: "Encrypted Guest",
  });
  const encLinkRes = await linkAccountRoute(encLinkReq as any);
  assert(encLinkRes.status === 200, "Encrypted link-account returns 200 OK");
  assert(encLinkRes.headers.get("X-Encrypted") === "1", "Encrypted link-account returns encrypted response");
  const encLinkRaw = await encLinkRes.text();
  const encLinkData = decryptPayload<any>(encLinkRaw);
  assert(encLinkData.success === true, "Decrypted link-account indicates success");
  assert(encLinkData.user.name === "Encrypted Guest", "Decrypted user name matches");

  // 10.2 Encrypted promo redemption
  const encPromoReq = makeEncryptedReq("http://localhost/api/subscription/promo", {
    code: "PROMO_PRO_2026",
    deviceId: encGuestDeviceId,
  });
  const encPromoRes = await promoSubRoute(encPromoReq as any);
  assert(encPromoRes.status === 200, "Encrypted promo redemption returns 200 OK");
  assert(encPromoRes.headers.get("X-Encrypted") === "1", "Encrypted promo returns encrypted response");
  const encPromoRaw = await encPromoRes.text();
  const encPromoData = decryptPayload<any>(encPromoRaw);
  assert(encPromoData.success === true, "Decrypted promo indicates success");

  // 10.3 Encrypted verify with lifetime ULTRA
  const encVerifyReq = makeEncryptedReq("http://localhost/api/subscription/verify", {
    receipt: `mock_receipt_ultra_lifetime_${Date.now()}`,
    provider: "mock",
    tier: "ULTRA",
    billingPeriod: "lifetime",
    deviceId: encGuestDeviceId,
  });
  const encVerifyRes = await verifySubRoute(encVerifyReq as any);
  assert(encVerifyRes.status === 200, "Encrypted verify returns 200 OK");
  assert(encVerifyRes.headers.get("X-Encrypted") === "1", "Encrypted verify returns encrypted response");
  const encVerifyRaw = await encVerifyRes.text();
  const encVerifyData = decryptPayload<any>(encVerifyRaw);
  assert(encVerifyData.valid === true, "Decrypted receipt verification is valid");
  assert(encVerifyData.tier === "ULTRA", "Decrypted tier is ULTRA");

  const ultraSub = await prisma.subscription.findFirst({
    where: { deviceId: encGuestDeviceId, tier: "ULTRA" },
  });
  const tenYearsFromNow = Date.now() + 10 * 365 * 24 * 3600 * 1000;
  assert(
    (ultraSub?.currentPeriodEnd.getTime() || 0) > tenYearsFromNow,
    "Lifetime ULTRA subscription has >10 years validity period"
  );

  // 10.4 User session precedence in authenticateRequest
  const testUserToken = await signAccessToken({
    sub: "usr_priority_test",
    email: "priority@liquidcalc.test",
    role: "user",
    type: "user",
  });
  const bothHeadersReq = new Request("http://localhost/api/test", {
    headers: {
      Authorization: `Bearer ${testUserToken}`,
      "X-Device-Token": "ios_guest_shadow_device",
    },
  });
  const authOutcome = await authenticateRequest(bothHeadersReq);
  assert(authOutcome.authenticated === true, "Combined request authenticates successfully");
  assert(authOutcome.type === "user", "User token takes precedence over device token");
  assert(authOutcome.user?.id === "usr_priority_test", "Authenticated user ID matches bearer token");

  console.log("\n========================================");
  console.log("SUBSCRIPTION & CLOUD SYNC AUDIT SUMMARY:");
  console.log(`Passed Checks: ${passed}`);
  console.log(`Failed Checks: ${failed}`);
  console.log(
    `Binary Verdict: ${failed === 0 ? "CLEAN (ALL SUBSCRIPTION, GUEST LINKING & CLOUD SYNC TESTS 100% OPERATIONAL)" : "FAILURE"}`
  );
  console.log("========================================\n");

  await prisma.$disconnect();
}

runSubscriptionTestSuite().catch(async (err) => {
  console.error("Fatal Subscription Test Error:", err);
  await prisma.$disconnect().catch(() => {});
  process.exit(1);
});
