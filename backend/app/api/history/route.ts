import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { historyStore, HistoryItem } from "@/lib/storage";
import { authenticateRequest } from "@/lib/auth";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function GET(req: NextRequest) {
  const searchParams = req.nextUrl.searchParams;

  const mode = searchParams.get("mode") || undefined;
  const deviceId = searchParams.get("deviceId") || undefined;
  const userId = searchParams.get("userId") || undefined;
  const search = searchParams.get("search") || searchParams.get("q") || undefined;
  const since = searchParams.get("since") || undefined;
  const limit = searchParams.get("limit") ? parseInt(searchParams.get("limit")!, 10) : 50;
  const offset = searchParams.get("offset") ? parseInt(searchParams.get("offset")!, 10) : 0;

  const result = historyStore.list({
    mode,
    deviceId,
    userId,
    search,
    since,
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

export async function POST(req: NextRequest) {
  let body: any = {};
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON request body" }, 400);
  }

  const expression = String(body.expression || "").trim();
  const result = String(body.result || "").trim();
  const mode = String(body.mode || "standard").toLowerCase().trim();
  const notes = body.notes ? String(body.notes) : undefined;
  const deviceId = typeof body.deviceId === "string" ? body.deviceId : "unknown";

  if (!expression && !result) {
    return jsonResponse(
      { error: "Missing required parameters: expression or result must be provided" },
      400
    );
  }

  // Check authentication to link userId if present
  const auth = await authenticateRequest(req);
  const userId =
    body.userId ||
    (auth.authenticated && auth.type === "user" && auth.user ? auth.user.id : undefined);

  const id = body.id || `calc_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  const now = new Date().toISOString();

  const syncRes = historyStore.sync(
    [
      {
        id,
        timestamp: body.timestamp || now,
        expression,
        result,
        mode,
        notes,
        deviceId,
        userId,
        updatedAt: now,
      },
    ],
    deviceId,
    undefined,
    userId
  );

  const created = historyStore.get(id);

  return jsonResponse(
    {
      success: true,
      message: "Calculation recorded successfully",
      item: created,
      totalRecords: syncRes.totalRecords,
    },
    201
  );
}
