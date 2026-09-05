import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { telemetryStore } from "@/lib/telemetry";
import { historyStore } from "@/lib/storage";
import { notesStore } from "@/lib/notes";
import { getActiveSessionsCount } from "@/lib/auth";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function GET(req: NextRequest) {
  const telemetryStats = telemetryStore.getStats();
  const historyStats = historyStore.getStats();
  const notesStats = notesStore.getStats();
  const activeSessions = await getActiveSessionsCount();

  // Combine telemetry with store metrics for full analytical overview
  const payload = {
    success: true,
    timestamp: new Date().toISOString(),
    telemetry: {
      ...telemetryStats,
      activeSessions,
    },
    calculations: {
      totalStored: historyStats.totalCount,
      modesDistribution: historyStats.modesCount,
      lastUpdated: historyStats.lastUpdated,
    },
    notebooks: {
      totalNotes: notesStats.totalCount,
      tagsCount: notesStats.tagsCount,
      lastUpdated: notesStats.lastUpdated,
    },
  };

  return jsonResponse(payload, {
    status: 200,
    headers: {
      "Cache-Control": "no-store, no-cache, must-revalidate",
    },
  });
}
