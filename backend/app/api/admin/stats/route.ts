import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { verifyAdminRequest } from "@/lib/admin";
import { prisma } from "@/lib/prisma";
import { telemetryStore } from "@/lib/telemetry";
import { historyStore } from "@/lib/storage";
import { notesStore } from "@/lib/notes";
import { getActiveSessionsCount } from "@/lib/auth";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

/**
 * GET /api/admin/stats
 * High-level executive KPI overview for dashboard widgets.
 */
export async function GET(req: NextRequest) {
  const auth = await verifyAdminRequest(req);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.error }, auth.status);
  }

  try {
    const [
      totalUsers,
      totalDevices,
      activeSessions,
      activeSubs,
      calculationsCount,
      notesCount,
    ] = await Promise.all([
      prisma.user.count(),
      prisma.deviceToken.count(),
      getActiveSessionsCount(),
      prisma.subscription.findMany({
        where: { status: "active" },
        include: { plan: true },
      }),
      prisma.calculation.count(),
      prisma.note.count(),
    ]);

    const telemStats = telemetryStore.getStats();
    const historyStats = historyStore.getStats();
    const notesStats = notesStore.getStats();

    let estimatedMrr = 0;
    const tierCounts: Record<string, number> = { FREE: 0, PRO: 0, ULTRA: 0 };

    for (const sub of activeSubs) {
      const tier = (sub.tier || "FREE").toUpperCase();
      tierCounts[tier] = (tierCounts[tier] || 0) + 1;

      const price = sub.plan?.priceUsd || (tier === "ULTRA" ? 9.99 : tier === "PRO" ? 4.99 : 0);
      const period = sub.plan?.billingPeriod || "monthly";
      if (period === "monthly") {
        estimatedMrr += price;
      } else if (period === "yearly") {
        estimatedMrr += price / 12;
      }
    }

    const totalEvents = telemStats.totalEvents || 1;
    const totalCrashes = telemStats.crashCount || 0;
    const stabilityRatePct = Number(
      Math.max(0, 100 - (totalCrashes / totalEvents) * 100).toFixed(2)
    );

    return jsonResponse(
      {
        success: true,
        stats: {
          totalUsers,
          totalDevices,
          activeSessions,
          activeSubscriptions: activeSubs.length,
          tierBreakdown: tierCounts,
          estimatedMrr: Number(estimatedMrr.toFixed(2)),
          totalCalculations: Math.max(calculationsCount, historyStats.totalCount),
          totalNotes: Math.max(notesCount, notesStats.totalCount),
          totalCrashes,
          stabilityRatePct,
          averageLatencyMs: telemStats.averagePerformanceLatencyMs || 34,
        },
      },
      200
    );
  } catch (err: any) {
    return jsonResponse({ error: "Failed to compile admin stats", details: err.message }, 500);
  }
}
