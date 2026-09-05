import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { telemetryStore } from "@/lib/telemetry";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function GET(req: NextRequest) {
  const searchParams = req.nextUrl.searchParams;

  const type = searchParams.get("type") || undefined;
  const deviceId = searchParams.get("deviceId") || undefined;
  const limit = searchParams.get("limit") ? parseInt(searchParams.get("limit")!, 10) : 25;
  const offset = searchParams.get("offset") ? parseInt(searchParams.get("offset")!, 10) : 0;

  const result = telemetryStore.list({
    type,
    deviceId,
    limit,
    offset,
  });

  return jsonResponse(result, {
    status: 200,
    headers: {
      "Cache-Control": "no-store, no-cache, must-revalidate",
    },
  });
}
