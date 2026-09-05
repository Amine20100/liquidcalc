import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { notesStore, NoteItem } from "@/lib/notes";

import { authenticateRequest } from "@/lib/auth";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function POST(req: NextRequest) {
  let body: {
    deviceId?: string;
    notes?: NoteItem[];
    items?: NoteItem[]; // alias for compatibility
    since?: string;
  } = {};

  try {
    body = await req.json();
  } catch {
    return jsonResponse(
      { error: "Invalid JSON request body" },
      { status: 400 }
    );
  }

  const rawList = body.notes || body.items;
  if (!body || typeof body !== "object" || !Array.isArray(rawList)) {
    return jsonResponse(
      { error: "Missing or invalid required field 'notes' (must be an array)" },
      { status: 400 }
    );
  }

  const notes = rawList;
  const deviceId = body.deviceId || "web-client";
  const since =
    (typeof body.since === "string" && body.since.trim()) ||
    req.nextUrl.searchParams.get("since") ||
    undefined;

  const auth = await authenticateRequest(req);
  const userId =
    auth.authenticated && auth.type === "user" && auth.user
      ? auth.user.id
      : undefined;

  const result = await notesStore.sync(notes, deviceId, since, userId);

  return jsonResponse(result, { status: 200 });
}
