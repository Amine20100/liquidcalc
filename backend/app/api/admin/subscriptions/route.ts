import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { verifyAdminRequest, listAdminSubscriptions } from "@/lib/admin";
import { prisma } from "@/lib/prisma";
import { getTierLimits } from "@/lib/subscription";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

/**
 * GET /api/admin/subscriptions
 * Inspect active subscriptions, billing providers, MRR, and expiration dates.
 */
export async function GET(req: NextRequest) {
  const auth = await verifyAdminRequest(req);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.error }, auth.status);
  }

  const { searchParams } = req.nextUrl;
  const tier = searchParams.get("tier") || undefined;
  const status = searchParams.get("status") || undefined;
  const provider = searchParams.get("provider") || undefined;
  const search = searchParams.get("search") || undefined;
  const page = searchParams.get("page") ? parseInt(searchParams.get("page")!, 10) : 1;
  const limit = searchParams.get("limit") ? parseInt(searchParams.get("limit")!, 10) : 25;

  try {
    const data = await listAdminSubscriptions({
      tier,
      status,
      provider,
      search,
      page,
      limit,
    });
    return jsonResponse(data, 200);
  } catch (err: any) {
    return jsonResponse({ error: "Failed to list subscriptions", details: err.message }, 500);
  }
}

/**
 * PATCH /api/admin/subscriptions
 * Modify subscription status (cancel, extend, change tier).
 */
export async function PATCH(req: NextRequest) {
  const auth = await verifyAdminRequest(req);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.error }, auth.status);
  }

  let body: any = {};
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const { id, action, status, days, tier } = body;
  if (!id) {
    return jsonResponse({ error: "Subscription id is required" }, 400);
  }

  try {
    const existing = await prisma.subscription.findUnique({
      where: { id },
    });

    if (!existing) {
      return jsonResponse({ error: "Subscription not found" }, 404);
    }

    // Cancel action
    if (action === "cancel" || status === "canceled") {
      const updated = await prisma.subscription.update({
        where: { id },
        data: {
          status: "canceled",
          cancelAtPeriodEnd: true,
          updatedAt: new Date(),
        },
      });
      return jsonResponse(
        { success: true, message: "Subscription cancelled successfully", subscription: updated },
        200
      );
    }

    // Extend action
    if (action === "extend" || days) {
      const extendDays = Number(days) || 30;
      const currentEnd = new Date(existing.currentPeriodEnd).getTime();
      const newEnd = new Date(Math.max(Date.now(), currentEnd) + extendDays * 24 * 3600 * 1000);

      const updated = await prisma.subscription.update({
        where: { id },
        data: {
          currentPeriodEnd: newEnd,
          status: "active",
          updatedAt: new Date(),
        },
      });

      // Also update entitlement validity
      const conditions: any[] = [];
      if (existing.userId) conditions.push({ userId: existing.userId });
      if (existing.deviceId) conditions.push({ deviceId: existing.deviceId });
      if (conditions.length > 0) {
        await prisma.entitlement.updateMany({
          where: { OR: conditions },
          data: { validUntil: newEnd },
        });
      }

      return jsonResponse(
        {
          success: true,
          message: `Subscription extended by ${extendDays} days`,
          subscription: updated,
        },
        200
      );
    }

    // Change tier action
    if (action === "change_tier" || tier) {
      const targetTier = (tier || "PRO").toUpperCase();
      const updated = await prisma.subscription.update({
        where: { id },
        data: {
          tier: targetTier,
          updatedAt: new Date(),
        },
      });

      const limits = getTierLimits(targetTier);
      const conditions: any[] = [];
      if (existing.userId) conditions.push({ userId: existing.userId });
      if (existing.deviceId) conditions.push({ deviceId: existing.deviceId });
      if (conditions.length > 0) {
        await prisma.entitlement.updateMany({
          where: { OR: conditions },
          data: {
            tier: targetTier,
            maxCloudSyncItems: limits.maxCloudSyncItems,
            canOtaSign: limits.canOtaSign,
            priorityAi: limits.priorityAi,
            customThemes: limits.customThemes,
          },
        });
      }

      return jsonResponse(
        {
          success: true,
          message: `Subscription tier updated to ${targetTier}`,
          subscription: updated,
        },
        200
      );
    }

    return jsonResponse({ error: "Unsupported subscription action" }, 400);
  } catch (err: any) {
    return jsonResponse({ error: "Failed to update subscription", details: err.message }, 500);
  }
}
