import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { historyStore } from "@/lib/storage";
import { notesStore } from "@/lib/notes";
import { telemetryStore } from "@/lib/telemetry";
import { getActiveSessionsCount } from "@/lib/auth";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function GET(req: NextRequest) {
  const historyStats = historyStore.getStats();
  const notesStats = notesStore.getStats();
  const telemetryStats = telemetryStore.getStats();
  const activeSessions = await getActiveSessionsCount();

  const payload = {
    status: "operational",
    healthy: true,
    timestamp: new Date().toISOString(),
    uptime: typeof process.uptime === "function" ? Math.floor(process.uptime()) : 120,
    version: "2.3.0",
    environment: process.env.NODE_ENV || "production",
    region: process.env.VERCEL_REGION || "iad1",
    services: {
      gemini_gateway: {
        status: "operational",
        model: "gemini-2.5-flash",
        features: ["sse_streaming", "multimodal_ocr", "latex_tutor", "structured_json"],
      },
      ota_signer: {
        status: "operational",
        bundleId: "com.liquidcalc.app",
        dtd: "Apple Software Package DTD 1.0",
        action: "itms-services",
      },
      updates_dist: {
        status: "operational",
        latestVersion: "2.3.0",
        buildNumber: "23",
      },
      history_sync: {
        status: "operational",
        recordsCount: historyStats.totalCount,
        lastUpdated: historyStats.lastUpdated,
      },
      notes_sync: {
        status: "operational",
        notesCount: notesStats.totalCount,
        tagsCount: notesStats.tagsCount,
        lastUpdated: notesStats.lastUpdated,
      },
      auth_service: {
        status: "operational",
        jwtAlgorithm: "HS256",
        features: ["bearer_jwt", "device_tokens", "api_keys", "session_management"],
        activeSessions,
      },
      telemetry_analytics: {
        status: "operational",
        totalEvents: telemetryStats.totalEvents,
        crashCount: telemetryStats.crashCount,
        crashRatePct: telemetryStats.crashRatePct,
      },
      database_sqlite: {
        status: "operational",
        provider: "sqlite",
        orm: "prisma",
        location: "dev.db",
      },
    },
  };

  return jsonResponse(payload, {
    status: 200,
    headers: {
      "Cache-Control": "no-store, no-cache, must-revalidate",
    },
  });
}
