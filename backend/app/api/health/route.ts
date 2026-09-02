import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { historyStore } from "@/lib/storage";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function GET(req: NextRequest) {
  const stats = historyStore.getStats();

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
        recordsCount: stats.totalCount,
        lastUpdated: stats.lastUpdated,
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
