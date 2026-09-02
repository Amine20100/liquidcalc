import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { historyStore } from "@/lib/storage";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function GET(req: NextRequest) {
  const searchParams = req.nextUrl.searchParams;

  const mode = searchParams.get("mode") || undefined;
  const deviceId = searchParams.get("deviceId") || undefined;
  const search = searchParams.get("search") || searchParams.get("q") || undefined;
  const limit = searchParams.get("limit") ? parseInt(searchParams.get("limit")!, 10) : 50;
  const offset = searchParams.get("offset") ? parseInt(searchParams.get("offset")!, 10) : 0;

  const result = historyStore.list({
    mode,
    deviceId,
    search,
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
