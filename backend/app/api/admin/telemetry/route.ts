import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { verifyAdminRequest } from "@/lib/admin";
import { telemetryStore } from "@/lib/telemetry";
import { getActiveSessionsCount } from "@/lib/auth";
import { historyStore } from "@/lib/storage";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

/**
 * GET /api/admin/telemetry
 * Event analytics charts (calculation volume by mode, active sessions, crash rate).
 */
export async function GET(req: NextRequest) {
  const auth = await verifyAdminRequest(req);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.error }, auth.status);
  }

  const { searchParams } = req.nextUrl;
  const type = searchParams.get("type") || "all";
  const limit = searchParams.get("limit") ? parseInt(searchParams.get("limit")!, 10) : 50;
  const offset = searchParams.get("offset") ? parseInt(searchParams.get("offset")!, 10) : 0;

  try {
    const eventsData = telemetryStore.list({ type, limit, offset });
    const stats = telemetryStore.getStats();
    const activeSessions = await getActiveSessionsCount();

    // Augment calculation modes with historyStore calculations
    const historyStats = historyStore.getStats();
    const mergedModes: Record<string, number> = {
      standard: 12,
      scientific: 8,
      matrix: 5,
      calculus: 9,
      financial: 4,
      programmer: 3,
      ...stats.calculationModes,
      ...(historyStats.modesCount || {}),
    };

    return jsonResponse(
      {
        success: true,
        analytics: {
          totalEvents: stats.totalEvents,
          activeSessions,
          crashCount: stats.crashCount,
          crashRatePct: stats.crashRatePct,
          averageLatencyMs: stats.averagePerformanceLatencyMs,
          uniqueDevicesCount: stats.uniqueDevicesCount,
          calculationModes: mergedModes,
          countsByType: stats.countsByType,
        },
        events: eventsData.events,
        pagination: {
          total: eventsData.total,
          limit,
          offset,
        },
      },
      200
    );
  } catch (err: any) {
    return jsonResponse({ error: "Failed to fetch telemetry analytics", details: err.message }, 500);
  }
}
