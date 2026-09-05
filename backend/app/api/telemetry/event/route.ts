import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { telemetryStore } from "@/lib/telemetry";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function POST(req: NextRequest) {
  let body: any = {};
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON request body" }, 400);
  }

  const rawType = String(body.type || "usage").toLowerCase();
  const validTypes = ["crash", "performance", "calculation", "usage"];
  const type = (validTypes.includes(rawType) ? rawType : "usage") as
    | "crash"
    | "performance"
    | "calculation"
    | "usage";

  const name = body.name || body.eventName || "event";
  const payload = body.payload || body.data || {};
  const deviceId = body.deviceId || "unknown";
  const appVersion = body.appVersion || "2.3.0";
  const osVersion = body.osVersion || undefined;

  const record = await telemetryStore.record({
    type,
    name: String(name),
    payload,
    deviceId,
    appVersion,
    osVersion,
  });

  return jsonResponse(
    {
      success: true,
      message: "Telemetry event recorded",
      eventId: record.id,
      timestamp: record.createdAt,
    },
    201
  );
}
