import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { verifyAdminRequest, getSystemHealthMetrics } from "@/lib/admin";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

/**
 * GET /api/admin/health
 * SQLite database metrics, Edge function latency, Gemini API quota status, OTA downloads.
 */
export async function GET(req: NextRequest) {
  const auth = await verifyAdminRequest(req);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.error }, auth.status);
  }

  try {
    const metrics = await getSystemHealthMetrics();
    return jsonResponse(
      {
        success: true,
        ...metrics,
      },
      200
    );
  } catch (err: any) {
    return jsonResponse(
      { error: "Failed to evaluate system health", details: err.message },
      500
    );
  }
}
