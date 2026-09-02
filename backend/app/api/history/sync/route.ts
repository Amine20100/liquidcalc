import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { historyStore, HistoryItem } from "@/lib/storage";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function POST(req: NextRequest) {
  let body: {
    deviceId?: string;
    items?: HistoryItem[];
  } = {};

  try {
    body = await req.json();
  } catch {
    return jsonResponse(
      { error: "Invalid JSON request body" },
      { status: 400 }
    );
  }

  if (!body || typeof body !== "object" || !Array.isArray(body.items)) {
    return jsonResponse(
      { error: "Missing or invalid required field 'items' (must be an array)" },
      { status: 400 }
    );
  }

  const items = body.items;
  const deviceId = body.deviceId || "web-client";

  const result = historyStore.sync(items, deviceId);

  return jsonResponse(result, { status: 200 });
}
