import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { getActiveSessionsCount, listActiveSessions, revokeSession } from "@/lib/auth";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function GET(req: NextRequest) {
  const searchParams = req.nextUrl.searchParams;
  const limit = searchParams.get("limit") ? parseInt(searchParams.get("limit")!, 10) : 20;

  const count = await getActiveSessionsCount();
  const sessions = await listActiveSessions(limit);

  // Mask tokens for security
  const safeSessions = sessions.map((s) => ({
    id: s.id,
    maskedToken: s.token.length > 12 ? `${s.token.substring(0, 6)}...${s.token.slice(-4)}` : "***",
    user: s.user,
    device: s.device,
    expiresAt: s.expiresAt,
    createdAt: s.createdAt,
  }));

  return jsonResponse(
    {
      success: true,
      activeSessionsCount: count,
      count: safeSessions.length,
      sessions: safeSessions,
    },
    200
  );
}

export async function DELETE(req: NextRequest) {
  const searchParams = req.nextUrl.searchParams;
  let id = searchParams.get("id") || searchParams.get("token");

  if (!id) {
    try {
      const body = await req.json();
      id = body.id || body.token;
    } catch {
      // Ignore
    }
  }

  if (!id) {
    return jsonResponse({ error: "Session id or token is required" }, 400);
  }

  const success = await revokeSession(id);
  return jsonResponse({ success, message: success ? "Session revoked" : "Session not found" }, 200);
}
