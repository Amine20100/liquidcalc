import crypto from "crypto";
import { prisma } from "./prisma";
import { historyStore } from "./storage";
import { notesStore } from "./notes";
import {
  hashPassword,
  comparePassword,
  signAccessToken,
  signRefreshToken,
  createSession,
} from "./auth";

export type TierType = "FREE" | "PRO" | "ULTRA";

export const TIER_RANK: Record<string, number> = {
  ULTRA: 3,
  PRO: 2,
  FREE: 1,
};

export interface TierEntitlements {
  tier: TierType;
  maxCloudSyncItems: number; // 50 for FREE, -1 for unlimited
  canOtaSign: boolean;
  priorityAi: boolean;
  customThemes: boolean;
  exportFormats: string[];
  maxDevices: number;
}

export const TIER_LIMITS: Record<TierType, TierEntitlements> = {
  FREE: {
    tier: "FREE",
    maxCloudSyncItems: 50,
    canOtaSign: false,
    priorityAi: false,
    customThemes: false,
    exportFormats: ["txt", "csv"],
    maxDevices: 1,
  },
  PRO: {
    tier: "PRO",
    maxCloudSyncItems: -1, // Unlimited
    canOtaSign: true,
    priorityAi: false,
    customThemes: true,
    exportFormats: ["txt", "csv", "json", "latex", "pdf"],
    maxDevices: 5,
  },
  ULTRA: {
    tier: "ULTRA",
    maxCloudSyncItems: -1, // Unlimited
    canOtaSign: true,
    priorityAi: true,
    customThemes: true,
    exportFormats: ["txt", "csv", "json", "latex", "pdf", "docx", "typst"],
    maxDevices: -1, // Unlimited
  },
};

export const DEFAULT_PLANS = [
  {
    id: "plan_free",
    name: "LiquidCalc Free",
    tier: "FREE",
    priceUsd: 0.0,
    billingPeriod: "lifetime",
    features: JSON.stringify([
      "Standard math and unit converter engines",
      "Basic local calculation history",
      "Cloud sync quota: up to 50 items",
      "Standard Markdown math notes",
      "1 active device",
    ]),
    description: "Essential precision calculator for everyday tasks.",
  },
  {
    id: "plan_pro_monthly",
    name: "LiquidCalc Pro Monthly",
    tier: "PRO",
    priceUsd: 4.99,
    billingPeriod: "monthly",
    features: JSON.stringify([
      "Unlimited multi-device cloud synchronization",
      "Full markdown math notebook with rich attachments",
      "Ad-free calculation experience",
      "LaTeX and PDF document export",
      "Over-The-Air (OTA) iOS enterprise app signing",
      "Up to 5 active devices",
    ]),
    description: "Advanced math suite for power users and students.",
  },
  {
    id: "plan_pro_yearly",
    name: "LiquidCalc Pro Yearly",
    tier: "PRO",
    priceUsd: 39.99,
    billingPeriod: "yearly",
    features: JSON.stringify([
      "Everything in Pro Monthly included (Save 33%)",
      "Unlimited cloud sync across all devices",
      "LaTeX, PDF, and CSV exports",
      "OTA Enterprise signing",
      "Up to 5 active devices",
    ]),
    description: "Best value for full-year Pro capabilities.",
  },
  {
    id: "plan_ultra_monthly",
    name: "LiquidCalc Ultra Monthly",
    tier: "ULTRA",
    priceUsd: 9.99,
    billingPeriod: "monthly",
    features: JSON.stringify([
      "Everything in Pro included",
      "Priority Gemini 2.5 Pro streaming AI math solver",
      "Instant OCR handwritten math & receipt scanner",
      "Unlimited OTA app signing with custom provisioning profiles",
      "Unlimited devices with real-time sync conflict resolution",
      "Custom UI themes and typography",
      "VIP priority support",
    ]),
    description: "Ultimate mathematical intelligence & enterprise OTA power.",
  },
  {
    id: "plan_ultra_yearly",
    name: "LiquidCalc Ultra Yearly",
    tier: "ULTRA",
    priceUsd: 79.99,
    billingPeriod: "yearly",
    features: JSON.stringify([
      "Everything in Ultra Monthly included (Save 33%)",
      "Priority Gemini 2.5 Pro streaming AI solver",
      "Instant OCR handwritten math & receipt scanner",
      "Unlimited OTA enterprise app signing",
      "Unlimited devices & real-time sync",
    ]),
    description: "Best value for full-year Ultra access.",
  },
  {
    id: "plan_ultra_lifetime",
    name: "LiquidCalc Ultra Lifetime",
    tier: "ULTRA",
    priceUsd: 199.99,
    billingPeriod: "lifetime",
    features: JSON.stringify([
      "Lifetime access to all Ultra capabilities forever",
      "All future updates & major version upgrades included",
      "Priority AI solver and unlimited cloud sync forever",
      "Founding supporter badge & VIP support",
    ]),
    description: "One-time purchase for perpetual Ultra membership.",
  },
];

export const DEFAULT_PROMO_CODES = [
  { code: "PROMO_PRO_2026", tier: "PRO", durationDays: 30, maxUses: 1000 },
  { code: "PROMO_ULTRA_VIP", tier: "ULTRA", durationDays: 90, maxUses: 500 },
  { code: "LIQUIDCALC_FREE_TRIAL", tier: "PRO", durationDays: 14, maxUses: 10000 },
  { code: "STUDENT2026", tier: "PRO", durationDays: 180, maxUses: 5000 },
  { code: "TEST_ULTRA", tier: "ULTRA", durationDays: 30, maxUses: 1000 },
];

let plansSeeded = false;

/**
 * Ensures standard plans and promo codes exist in the database.
 */
export async function seedPlansAndPromoCodes(): Promise<void> {
  if (plansSeeded) return;

  try {
    for (const plan of DEFAULT_PLANS) {
      await prisma.plan.upsert({
        where: { id: plan.id },
        update: {
          name: plan.name,
          tier: plan.tier,
          priceUsd: plan.priceUsd,
          billingPeriod: plan.billingPeriod,
          features: plan.features,
          description: plan.description,
        },
        create: {
          id: plan.id,
          name: plan.name,
          tier: plan.tier,
          priceUsd: plan.priceUsd,
          billingPeriod: plan.billingPeriod,
          features: plan.features,
          description: plan.description,
          active: true,
        },
      });
    }

    for (const promo of DEFAULT_PROMO_CODES) {
      await prisma.promoCode.upsert({
        where: { code: promo.code },
        update: {},
        create: {
          code: promo.code,
          tier: promo.tier,
          durationDays: promo.durationDays,
          maxUses: promo.maxUses,
          currentUses: 0,
          active: true,
        },
      });
    }
    plansSeeded = true;
  } catch (err) {
    // Non-fatal, fallback to memory
  }
}

/**
 * Returns tier limits configuration for a given tier.
 */
export function getTierLimits(tier: string): TierEntitlements {
  const norm = (tier || "FREE").toUpperCase().trim() as TierType;
  return TIER_LIMITS[norm] || TIER_LIMITS.FREE;
}

/**
 * Helper to guarantee a DeviceToken row exists before referencing it.
 */
async function ensureDeviceToken(deviceId: string, userId?: string) {
  try {
    return await prisma.deviceToken.upsert({
      where: { deviceId },
      update: {
        userId: userId || undefined,
        lastActiveAt: new Date(),
      },
      create: {
        deviceId,
        token: `dev_${deviceId}_${crypto.randomUUID()}`,
        platform: "ios",
        name: "LiquidCalc Mobile Client",
        userId: userId || undefined,
      },
    });
  } catch {
    return null;
  }
}

/**
 * Evaluates active tier for a user or device, checking database subscriptions.
 */
export async function getUserOrDeviceSubscription(params: {
  userId?: string;
  deviceId?: string;
}) {
  await seedPlansAndPromoCodes();

  const now = new Date();
  let sub: any = null;

  // 1. Check user subscription if userId provided
  if (params.userId) {
    const userSubs = await prisma.subscription.findMany({
      where: {
        userId: params.userId,
        status: { in: ["active", "trialing"] },
        currentPeriodEnd: { gt: now },
      },
      include: { plan: true },
    });

    if (userSubs.length > 0) {
      userSubs.sort((a, b) => {
        const rankA = TIER_RANK[a.tier.toUpperCase()] || 0;
        const rankB = TIER_RANK[b.tier.toUpperCase()] || 0;
        if (rankB !== rankA) return rankB - rankA;
        return b.currentPeriodEnd.getTime() - a.currentPeriodEnd.getTime();
      });
      sub = userSubs[0];
    }
  }

  // 2. Check device subscription if not found or guest mode
  if (!sub && params.deviceId) {
    const devSubs = await prisma.subscription.findMany({
      where: {
        deviceId: params.deviceId,
        status: { in: ["active", "trialing"] },
        currentPeriodEnd: { gt: now },
      },
      include: { plan: true },
    });

    if (devSubs.length > 0) {
      devSubs.sort((a, b) => {
        const rankA = TIER_RANK[a.tier.toUpperCase()] || 0;
        const rankB = TIER_RANK[b.tier.toUpperCase()] || 0;
        if (rankB !== rankA) return rankB - rankA;
        return b.currentPeriodEnd.getTime() - a.currentPeriodEnd.getTime();
      });
      sub = devSubs[0];
    }
  }

  const effectiveTier = (sub ? sub.tier.toUpperCase() : "FREE") as TierType;
  const limits = getTierLimits(effectiveTier);

  return {
    tier: effectiveTier,
    subscription: sub,
    entitlements: limits,
    isActive: Boolean(sub),
  };
}

/**
 * Calculates current period end timestamp based on billing interval.
 */
export function calculatePeriodEnd(
  billingPeriod: string = "monthly",
  durationDays?: number
): Date {
  const now = Date.now();
  if (durationDays && durationDays > 0) {
    return new Date(now + durationDays * 24 * 60 * 60 * 1000);
  }

  const normPeriod = billingPeriod.toLowerCase().trim();
  if (normPeriod === "yearly" || normPeriod === "annual") {
    return new Date(now + 365 * 24 * 60 * 60 * 1000);
  }
  if (normPeriod === "lifetime" || normPeriod === "perpetual") {
    return new Date(now + 100 * 365 * 24 * 60 * 60 * 1000); // 100 years
  }
  // Default to monthly (30 days)
  return new Date(now + 30 * 24 * 60 * 60 * 1000);
}

/**
 * Creates or updates a subscription for a user or device.
 */
export async function createSubscription(params: {
  userId?: string;
  deviceId?: string;
  planId?: string;
  tier?: TierType | string;
  billingPeriod?: string;
  provider?: string;
  receipt?: string;
  providerSubId?: string;
}) {
  await seedPlansAndPromoCodes();

  if (!params.userId && !params.deviceId) {
    throw new Error("Must provide either userId or deviceId to create a subscription");
  }

  if (params.deviceId) {
    await ensureDeviceToken(params.deviceId, params.userId);
  }

  let planId = params.planId;
  let targetTier = (params.tier || "PRO").toUpperCase() as TierType;
  let billingPeriod = (params.billingPeriod || "monthly").toLowerCase();

  // Find plan if provided or deduce appropriate default plan
  if (planId) {
    const foundPlan = await prisma.plan.findUnique({ where: { id: planId } });
    if (foundPlan) {
      targetTier = foundPlan.tier.toUpperCase() as TierType;
      billingPeriod = foundPlan.billingPeriod.toLowerCase();
    }
  } else {
    // Map tier + billingPeriod to standard plan ID
    const candidateId = `plan_${targetTier.toLowerCase()}_${billingPeriod}`;
    const foundPlan = await prisma.plan.findUnique({ where: { id: candidateId } });
    if (foundPlan) {
      planId = foundPlan.id;
    } else {
      planId = targetTier === "ULTRA" ? "plan_ultra_monthly" : "plan_pro_monthly";
    }
  }

  // Ensure plan exists in DB
  const plan = await prisma.plan.findUnique({ where: { id: planId } });
  if (!plan) {
    // Seed default if somehow missing
    await prisma.plan.create({
      data: {
        id: planId,
        name: `LiquidCalc ${targetTier}`,
        tier: targetTier,
        billingPeriod,
        active: true,
      },
    });
  }

  const currentPeriodStart = new Date();
  const currentPeriodEnd = calculatePeriodEnd(billingPeriod);
  const provider = params.provider || "mock";
  const providerSubId = params.providerSubId || `sub_${provider}_${Date.now()}`;

  // Check if existing active subscription can be updated
  let existingSub = null;
  if (params.userId) {
    existingSub = await prisma.subscription.findFirst({
      where: { userId: params.userId },
      orderBy: { createdAt: "desc" },
    });
  } else if (params.deviceId) {
    existingSub = await prisma.subscription.findFirst({
      where: { deviceId: params.deviceId },
      orderBy: { createdAt: "desc" },
    });
  }

  let subscription;
  if (existingSub) {
    subscription = await prisma.subscription.update({
      where: { id: existingSub.id },
      data: {
        userId: params.userId || existingSub.userId,
        deviceId: params.deviceId || existingSub.deviceId,
        planId,
        tier: targetTier,
        status: "active",
        provider,
        providerSubId,
        receipt: params.receipt || existingSub.receipt,
        currentPeriodStart,
        currentPeriodEnd,
        cancelAtPeriodEnd: false,
        updatedAt: new Date(),
      },
      include: { plan: true },
    });
  } else {
    subscription = await prisma.subscription.create({
      data: {
        userId: params.userId,
        deviceId: params.deviceId,
        planId,
        tier: targetTier,
        status: "active",
        provider,
        providerSubId,
        receipt: params.receipt,
        currentPeriodStart,
        currentPeriodEnd,
        cancelAtPeriodEnd: false,
      },
      include: { plan: true },
    });
  }

  // Upsert Entitlement
  const limits = getTierLimits(targetTier);
  const entitlementConditions: any[] = [];
  if (params.userId) entitlementConditions.push({ userId: params.userId });
  if (params.deviceId) entitlementConditions.push({ deviceId: params.deviceId });

  const existingEntitlement = entitlementConditions.length > 0
    ? await prisma.entitlement.findFirst({
        where: { OR: entitlementConditions },
      })
    : null;

  if (existingEntitlement) {
    await prisma.entitlement.update({
      where: { id: existingEntitlement.id },
      data: {
        userId: params.userId || existingEntitlement.userId,
        deviceId: params.deviceId || existingEntitlement.deviceId,
        tier: targetTier,
        maxCloudSyncItems: limits.maxCloudSyncItems,
        canOtaSign: limits.canOtaSign,
        priorityAi: limits.priorityAi,
        customThemes: limits.customThemes,
        exportFormats: JSON.stringify(limits.exportFormats),
        validUntil: currentPeriodEnd,
      },
    });
  } else {
    await prisma.entitlement.create({
      data: {
        userId: params.userId,
        deviceId: params.deviceId,
        tier: targetTier,
        maxCloudSyncItems: limits.maxCloudSyncItems,
        canOtaSign: limits.canOtaSign,
        priorityAi: limits.priorityAi,
        customThemes: limits.customThemes,
        exportFormats: JSON.stringify(limits.exportFormats),
        validUntil: currentPeriodEnd,
      },
    });
  }

  return {
    subscription,
    entitlements: limits,
    effectiveTier: targetTier,
  };
}

/**
 * Verifies purchase receipts (Mock checkout, Apple StoreKit, or Stripe).
 */
export async function verifySubscriptionReceipt(params: {
  receipt: string;
  provider?: string;
  tier?: string;
  billingPeriod?: string;
  planId?: string;
  userId?: string;
  deviceId?: string;
}) {
  const rawReceipt = String(params.receipt || "").trim();
  if (!rawReceipt) {
    return {
      valid: false,
      error: "Receipt string is empty or missing",
    };
  }

  const provider = (params.provider || "mock").toLowerCase();
  let grantedTier: TierType = "PRO";
  let billingPeriod = "monthly";
  let providerSubId = `tx_${Date.now()}`;

  // 1. Mock Test Checkout Verification
  if (provider === "mock" || rawReceipt.startsWith("mock_") || rawReceipt.startsWith("test_")) {
    if (rawReceipt.includes("ultra") || (params.tier && params.tier.toUpperCase() === "ULTRA")) {
      grantedTier = "ULTRA";
    } else {
      grantedTier = "PRO";
    }
    if (params.billingPeriod) {
      billingPeriod = params.billingPeriod;
    } else if (rawReceipt.includes("yearly") || rawReceipt.includes("annual")) {
      billingPeriod = "yearly";
    } else if (rawReceipt.includes("lifetime") || grantedTier === "ULTRA") {
      billingPeriod = "lifetime";
    }
    providerSubId = `mock_tx_${Date.now()}`;
  }
  // 2. Apple StoreKit Receipt Verification (base64 or JWS mock decode)
  else if (provider === "apple_storekit" || provider === "apple") {
    try {
      let decodedStr = "";
      // If JWS token (3 dot-separated base64url parts), extract payload part
      if (rawReceipt.includes(".")) {
        const parts = rawReceipt.split(".");
        if (parts.length >= 2) {
          try {
            decodedStr = Buffer.from(parts[1], "base64url").toString("utf8");
          } catch {
            decodedStr = Buffer.from(parts[1], "base64").toString("utf8");
          }
        }
      }
      if (!decodedStr) {
        try {
          decodedStr = Buffer.from(rawReceipt, "base64").toString("utf8");
        } catch {
          decodedStr = rawReceipt;
        }
      }

      const isUltra =
        (params.tier && params.tier.toUpperCase() === "ULTRA") ||
        decodedStr.toLowerCase().includes("ultra") ||
        decodedStr.includes("tier_ultra");

      grantedTier = isUltra ? "ULTRA" : "PRO";

      if (
        decodedStr.toLowerCase().includes("yearly") ||
        decodedStr.toLowerCase().includes("annual") ||
        (params.billingPeriod && params.billingPeriod.toLowerCase().includes("year"))
      ) {
        billingPeriod = "yearly";
      }

      providerSubId = `apple_tx_${Date.now()}`;
    } catch {
      grantedTier = (params.tier && params.tier.toUpperCase() === "ULTRA") ? "ULTRA" : "PRO";
    }
  }
  // 3. Stripe Checkout Session / Payment Intent
  else if (provider === "stripe" || rawReceipt.startsWith("cs_") || rawReceipt.startsWith("pi_")) {
    if (params.tier && params.tier.toUpperCase() === "ULTRA") {
      grantedTier = "ULTRA";
    } else {
      grantedTier = "PRO";
    }
    providerSubId = rawReceipt;
  }

  // Create or update subscription
  const result = await createSubscription({
    userId: params.userId,
    deviceId: params.deviceId,
    planId: params.planId,
    tier: grantedTier,
    billingPeriod,
    provider,
    receipt: rawReceipt,
    providerSubId,
  });

  return {
    valid: true,
    provider,
    tier: grantedTier,
    subscription: result.subscription,
    entitlements: result.entitlements,
  };
}

/**
 * Redeems a promotional code for either user or guest device.
 */
export async function redeemPromoCode(params: {
  code: string;
  userId?: string;
  deviceId?: string;
}) {
  await seedPlansAndPromoCodes();

  const code = String(params.code || "").toUpperCase().trim();
  if (!code) {
    return { success: false, error: "Promo code is required" };
  }

  const promo = await prisma.promoCode.findUnique({
    where: { code },
  });

  if (!promo) {
    return { success: false, error: "Invalid promo code" };
  }

  if (!promo.active) {
    return { success: false, error: "This promo code is no longer active" };
  }

  if (promo.expiresAt && new Date() > promo.expiresAt) {
    return { success: false, error: "This promo code has expired" };
  }

  if (promo.maxUses > 0 && promo.currentUses >= promo.maxUses) {
    return { success: false, error: "This promo code has reached its maximum redemption limit" };
  }

  // Prevent double redemption by the same user or device
  const promoConditions: any[] = [];
  if (params.userId) promoConditions.push({ userId: params.userId });
  if (params.deviceId) promoConditions.push({ deviceId: params.deviceId });

  if (promoConditions.length > 0) {
    const alreadyRedeemed = await prisma.subscription.findFirst({
      where: {
        provider: "promo",
        providerSubId: { startsWith: `promo_${code}_` },
        OR: promoConditions,
      },
    });

    if (alreadyRedeemed) {
      return {
        success: false,
        error: "This promo code has already been redeemed for this account or device",
      };
    }
  }

  // Increment redemption count
  await prisma.promoCode.update({
    where: { id: promo.id },
    data: { currentUses: { increment: 1 } },
  });

  const targetTier = promo.tier.toUpperCase() as TierType;
  const currentPeriodStart = new Date();
  const currentPeriodEnd = calculatePeriodEnd("custom", promo.durationDays);

  if (params.deviceId) {
    await ensureDeviceToken(params.deviceId, params.userId);
  }

  // Find or create plan for this promo
  const planId = targetTier === "ULTRA" ? "plan_ultra_monthly" : "plan_pro_monthly";

  // Create or update subscription
  let sub = promoConditions.length > 0
    ? await prisma.subscription.findFirst({
        where: { OR: promoConditions },
        orderBy: { createdAt: "desc" },
      })
    : null;

  if (sub) {
    sub = await prisma.subscription.update({
      where: { id: sub.id },
      data: {
        userId: params.userId || sub.userId,
        deviceId: params.deviceId || sub.deviceId,
        tier: targetTier,
        planId,
        status: "active",
        provider: "promo",
        providerSubId: `promo_${code}_${Date.now()}`,
        currentPeriodStart,
        currentPeriodEnd,
        updatedAt: new Date(),
      },
    });
  } else {
    sub = await prisma.subscription.create({
      data: {
        userId: params.userId,
        deviceId: params.deviceId,
        tier: targetTier,
        planId,
        status: "active",
        provider: "promo",
        providerSubId: `promo_${code}_${Date.now()}`,
        currentPeriodStart,
        currentPeriodEnd,
      },
    });
  }

  // Update Entitlements
  const limits = getTierLimits(targetTier);
  const existingEntitlement = promoConditions.length > 0
    ? await prisma.entitlement.findFirst({
        where: { OR: promoConditions },
      })
    : null;

  if (existingEntitlement) {
    await prisma.entitlement.update({
      where: { id: existingEntitlement.id },
      data: {
        userId: params.userId || existingEntitlement.userId,
        deviceId: params.deviceId || existingEntitlement.deviceId,
        tier: targetTier,
        maxCloudSyncItems: limits.maxCloudSyncItems,
        canOtaSign: limits.canOtaSign,
        priorityAi: limits.priorityAi,
        customThemes: limits.customThemes,
        exportFormats: JSON.stringify(limits.exportFormats),
        validUntil: currentPeriodEnd,
      },
    });
  } else {
    await prisma.entitlement.create({
      data: {
        userId: params.userId,
        deviceId: params.deviceId,
        tier: targetTier,
        maxCloudSyncItems: limits.maxCloudSyncItems,
        canOtaSign: limits.canOtaSign,
        priorityAi: limits.priorityAi,
        customThemes: limits.customThemes,
        exportFormats: JSON.stringify(limits.exportFormats),
        validUntil: currentPeriodEnd,
      },
    });
  }

  return {
    success: true,
    message: `Promo code applied successfully! Enjoy ${promo.durationDays} days of ${targetTier}.`,
    tier: targetTier,
    durationDays: promo.durationDays,
    expiresAt: currentPeriodEnd.toISOString(),
    subscription: sub,
  };
}

/**
 * Links an anonymous guest device to a registered email/password user account
 * without losing any calculations, notes, or active subscriptions.
 */
export async function linkGuestAccount(params: {
  deviceId: string;
  email?: string;
  password?: string;
  name?: string;
  authenticatedUserId?: string;
}) {
  const deviceId = params.deviceId.trim();
  if (!deviceId) {
    throw new Error("Missing required parameter: deviceId");
  }

  let user;

  // Option A: Link to existing authenticated user session
  if (params.authenticatedUserId) {
    user = await prisma.user.findUnique({
      where: { id: params.authenticatedUserId },
    });
    if (!user) {
      throw new Error("Authenticated user not found");
    }
  }
  // Option B: Login or Register via credentials
  else {
    const email = String(params.email || "").trim().toLowerCase();
    const password = String(params.password || "").trim();

    if (!email || !password) {
      throw new Error("Either authenticated user or email and password must be provided");
    }

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      // Authenticate password
      const match = await comparePassword(password, existing.passwordHash);
      if (!match) {
        throw new Error("Invalid password for existing user account");
      }
      user = existing;
    } else {
      // Register new user account with concurrency race protection
      const passwordHash = await hashPassword(password);
      try {
        user = await prisma.user.create({
          data: {
            email,
            passwordHash,
            name: params.name?.trim() || null,
            role: "user",
          },
        });
      } catch (err: any) {
        if (err.code === "P2002") {
          // Parallel creation race: another request created the user in the same millisecond
          const reloaded = await prisma.user.findUnique({ where: { email } });
          if (reloaded) {
            const match = await comparePassword(password, reloaded.passwordHash);
            if (!match) {
              throw new Error("Invalid password for existing user account");
            }
            user = reloaded;
          } else {
            throw err;
          }
        } else {
          throw err;
        }
      }
    }
  }

  // 1. Link DeviceToken to user
  await ensureDeviceToken(deviceId, user.id);
  await prisma.deviceToken.updateMany({
    where: { deviceId },
    data: { userId: user.id },
  });

  // 2. Migrate Calculations from guest device to user (both SQLite and in-memory store)
  const calcUpdate = await prisma.calculation.updateMany({
    where: { deviceId, userId: null },
    data: { userId: user.id },
  });
  const memCalcsMigrated = historyStore.linkDeviceToUser(deviceId, user.id);

  // 3. Migrate Notes from guest device to user (both SQLite and in-memory store)
  const noteUpdate = await prisma.note.updateMany({
    where: { deviceId, userId: null },
    data: { userId: user.id },
  });
  const memNotesMigrated = notesStore.linkDeviceToUser(deviceId, user.id);

  // 4. Migrate Subscriptions from guest device to user
  const subUpdate = await prisma.subscription.updateMany({
    where: { deviceId, userId: null },
    data: { userId: user.id },
  });

  // 5. Migrate Entitlements from guest device to user
  await prisma.entitlement.updateMany({
    where: { deviceId, userId: null },
    data: { userId: user.id },
  });

  // 6. Consolidate and reconcile entitlements: eliminate duplicates and ensure highest tier
  const allUserSubs = await prisma.subscription.findMany({
    where: {
      userId: user.id,
      status: { in: ["active", "trialing"] },
      currentPeriodEnd: { gt: new Date() },
    },
  });

  let bestTier: TierType = "FREE";
  for (const s of allUserSubs) {
    const t = s.tier.toUpperCase() as TierType;
    if ((TIER_RANK[t] || 0) > (TIER_RANK[bestTier] || 0)) {
      bestTier = t;
    }
  }

  const bestLimits = getTierLimits(bestTier);
  const userEntitlements = await prisma.entitlement.findMany({
    where: { userId: user.id },
    orderBy: { createdAt: "asc" },
  });

  if (userEntitlements.length > 0) {
    const primary = userEntitlements[0];
    await prisma.entitlement.update({
      where: { id: primary.id },
      data: {
        tier: bestTier,
        maxCloudSyncItems: bestLimits.maxCloudSyncItems,
        canOtaSign: bestLimits.canOtaSign,
        priorityAi: bestLimits.priorityAi,
        customThemes: bestLimits.customThemes,
        exportFormats: JSON.stringify(bestLimits.exportFormats),
      },
    });

    if (userEntitlements.length > 1) {
      const duplicateIds = userEntitlements.slice(1).map((d) => d.id);
      await prisma.entitlement.deleteMany({
        where: { id: { in: duplicateIds } },
      });
    }
  } else {
    try {
      await prisma.entitlement.create({
        data: {
          userId: user.id,
          deviceId,
          tier: bestTier,
          maxCloudSyncItems: bestLimits.maxCloudSyncItems,
          canOtaSign: bestLimits.canOtaSign,
          priorityAi: bestLimits.priorityAi,
          customThemes: bestLimits.customThemes,
          exportFormats: JSON.stringify(bestLimits.exportFormats),
        },
      });
    } catch {
      // In case parallel thread created it
    }
  }

  // Final cleanup safeguard: ensure strictly at most 1 entitlement remains for this user
  const finalCheck = await prisma.entitlement.findMany({
    where: { userId: user.id },
    orderBy: { createdAt: "asc" },
  });
  if (finalCheck.length > 1) {
    const surplusIds = finalCheck.slice(1).map((d) => d.id);
    await prisma.entitlement.deleteMany({
      where: { id: { in: surplusIds } },
    });
  }

  // Generate new user session tokens
  const accessToken = await signAccessToken({
    sub: user.id,
    email: user.email,
    role: user.role,
    type: "user",
  });

  const refreshToken = await signRefreshToken({
    sub: user.id,
    type: "user",
  });

  await createSession({
    token: accessToken,
    userId: user.id,
    deviceId,
    expiresInDays: 7,
  });

  // Get active subscription and tier after linking
  const { tier, entitlements } = await getUserOrDeviceSubscription({
    userId: user.id,
    deviceId,
  });

  return {
    success: true,
    message: "Guest device successfully linked to user account with all data preserved",
    user: {
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      tier,
    },
    migrated: {
      calculations: Math.max(calcUpdate.count, memCalcsMigrated),
      notes: Math.max(noteUpdate.count, memNotesMigrated),
      subscriptions: subUpdate.count,
    },
    entitlements,
    tokens: {
      accessToken,
      refreshToken,
      tokenType: "Bearer",
      expiresIn: 604800,
    },
  };
}

/**
 * Checks whether user/device has exceeded cloud sync quota for their tier.
 */
export async function checkCloudSyncQuota(params: {
  userId?: string;
  deviceId?: string;
  incomingCount: number;
}) {
  const { tier, entitlements } = await getUserOrDeviceSubscription(params);

  // Unlimited tier
  if (entitlements.maxCloudSyncItems === -1) {
    return {
      allowed: true,
      tier,
      currentCount: 0,
      maxAllowed: -1,
      remaining: Infinity,
    };
  }

  // Free tier quota evaluation
  const calcCount = historyStore.countForOwner(params);
  const noteCount = notesStore.countForOwner(params);
  const currentTotal = calcCount + noteCount;
  const maxQuota = entitlements.maxCloudSyncItems;

  if (currentTotal + params.incomingCount > maxQuota) {
    return {
      allowed: false,
      tier,
      currentCount: currentTotal,
      maxAllowed: maxQuota,
      remaining: Math.max(0, maxQuota - currentTotal),
      error: `Cloud sync quota exceeded for ${tier} tier (maximum ${maxQuota} items). Upgrade to PRO for unlimited multi-device cloud sync.`,
    };
  }

  return {
    allowed: true,
    tier,
    currentCount: currentTotal,
    maxAllowed: maxQuota,
    remaining: maxQuota - (currentTotal + params.incomingCount),
  };
}

/**
 * Processes incoming Stripe payment webhook events.
 */
export async function processStripeWebhook(payload: any, rawPayload: string) {
  const eventId = payload?.id || `evt_${Date.now()}`;
  const eventType = payload?.type || "unknown";
  const dataObject = payload?.data?.object || {};

  const webhookRecord = await prisma.paymentWebhook.create({
    data: {
      provider: "stripe",
      eventType,
      eventId,
      payload: typeof rawPayload === "string" ? rawPayload : JSON.stringify(payload),
      processed: true,
    },
  });

  try {
    if (eventType === "checkout.session.completed" || eventType === "invoice.paid") {
      const customerEmail = dataObject.customer_email || dataObject.customer_details?.email;
      const clientReferenceId = dataObject.client_reference_id; // could be userId or deviceId
      const amountPaid = (dataObject.amount_total || dataObject.amount_paid || 0) / 100;

      let userId = undefined;
      let deviceId = undefined;

      if (clientReferenceId) {
        if (clientReferenceId.startsWith("usr_") || clientReferenceId.length === 36) {
          userId = clientReferenceId;
        } else {
          deviceId = clientReferenceId;
        }
      }

      if (!userId && customerEmail) {
        const foundUser = await prisma.user.findUnique({ where: { email: customerEmail } });
        if (foundUser) userId = foundUser.id;
      }

      const tier: TierType = amountPaid > 15 ? "ULTRA" : "PRO";
      await createSubscription({
        userId,
        deviceId,
        tier,
        billingPeriod: amountPaid > 50 ? "yearly" : "monthly",
        provider: "stripe",
        providerSubId: dataObject.subscription || eventId,
        receipt: eventId,
      });
    } else if (
      eventType === "customer.subscription.deleted" ||
      eventType === "charge.refunded"
    ) {
      const subId = dataObject.subscription || dataObject.id;
      if (subId) {
        await prisma.subscription.updateMany({
          where: { providerSubId: subId },
          data: { status: "canceled" },
        });
      }
    }

    return { success: true, webhookId: webhookRecord.id };
  } catch (err: any) {
    await prisma.paymentWebhook.update({
      where: { id: webhookRecord.id },
      data: { error: err.message },
    });
    return { success: false, error: err.message };
  }
}

/**
 * Processes incoming Apple StoreKit Server Notifications (v2).
 */
export async function processAppleWebhook(payload: any, rawPayload: string) {
  const notificationType = payload?.notificationType || payload?.type || "SUBSCRIBED";
  const notificationId = payload?.notificationUUID || `apple_notif_${Date.now()}`;
  const subtype = payload?.subtype;

  const webhookRecord = await prisma.paymentWebhook.create({
    data: {
      provider: "apple_storekit",
      eventType: notificationType,
      eventId: notificationId,
      payload: typeof rawPayload === "string" ? rawPayload : JSON.stringify(payload),
      processed: true,
    },
  });

  try {
    // If notification represents cancellation, expiry, or refund
    if (
      notificationType === "EXPIRED" ||
      notificationType === "REVOKE" ||
      notificationType === "REFUND"
    ) {
      const originalTransactionId =
        payload?.data?.signedTransactionInfo?.originalTransactionId ||
        payload?.data?.originalTransactionId;
      if (originalTransactionId) {
        await prisma.subscription.updateMany({
          where: { providerSubId: originalTransactionId },
          data: { status: "expired" },
        });
      }
    } else if (
      notificationType === "SUBSCRIBED" ||
      notificationType === "DID_RENEW" ||
      notificationType === "OFFER_REDEEMED"
    ) {
      const originalTransactionId =
        payload?.data?.signedTransactionInfo?.originalTransactionId ||
        payload?.data?.originalTransactionId ||
        `apple_orig_${Date.now()}`;
      const appAccountToken =
        payload?.data?.signedTransactionInfo?.appAccountToken ||
        payload?.data?.appAccountToken;
      const productId =
        payload?.data?.signedTransactionInfo?.productId ||
        payload?.data?.productId ||
        "";

      const tier: TierType = productId.toLowerCase().includes("ultra") ? "ULTRA" : "PRO";
      const billingPeriod = productId.toLowerCase().includes("yearly") ? "yearly" : "monthly";

      let userId = undefined;
      let deviceId = undefined;
      if (appAccountToken) {
        if (appAccountToken.startsWith("usr_") || appAccountToken.length === 36) {
          userId = appAccountToken;
        } else {
          deviceId = appAccountToken;
        }
      }

      await createSubscription({
        userId,
        deviceId,
        tier,
        billingPeriod,
        provider: "apple_storekit",
        providerSubId: originalTransactionId,
        receipt: notificationId,
      });
    }

    return { success: true, webhookId: webhookRecord.id };
  } catch (err: any) {
    await prisma.paymentWebhook.update({
      where: { id: webhookRecord.id },
      data: { error: err.message },
    });
    return { success: false, error: err.message };
  }
}
