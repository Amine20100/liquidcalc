import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { notesStore } from "@/lib/notes";

import { authenticateRequest } from "@/lib/auth";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const id = params.id;
  const note = notesStore.get(id) || (await notesStore.getAsync(id));

  if (!note) {
    return jsonResponse({ error: "Note not found" }, 404);
  }

  return jsonResponse({ success: true, note }, 200);
}

export async function PUT(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const id = params.id;
  let body: any = {};
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON request body" }, 400);
  }

  const existing = notesStore.get(id) || (await notesStore.getAsync(id));
  const auth = await authenticateRequest(req);
  const userId =
    body.userId ||
    (auth.authenticated && auth.type === "user" && auth.user ? auth.user.id : undefined);

  const title =
    typeof body.title === "string"
      ? body.title.trim()
      : existing
      ? existing.title
      : "Untitled note";
  const markdown =
    typeof body.markdown === "string"
      ? body.markdown
      : existing
      ? existing.markdown
      : "";
  const tags = Array.isArray(body.tags)
    ? body.tags
    : existing
    ? existing.tags
    : ["study"];
  const attachments = Array.isArray(body.attachments)
    ? body.attachments
    : existing
    ? existing.attachments
    : [];
  const deviceId =
    typeof body.deviceId === "string"
      ? body.deviceId
      : existing
      ? existing.deviceId
      : "unknown";

  const now = new Date().toISOString();
  const createdAt = existing ? existing.createdAt : (body.createdAt || now);

  await notesStore.sync(
    [
      {
        id,
        title,
        markdown,
        tags,
        attachments,
        deviceId,
        userId: userId || existing?.userId,
        createdAt,
        updatedAt: now,
      },
    ],
    deviceId,
    undefined,
    userId || existing?.userId
  );

  const updated = notesStore.get(id);
  return jsonResponse(
    {
      success: true,
      message: "Note updated successfully",
      note: updated,
    },
    200
  );
}

export async function DELETE(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const id = params.id;
  const deleted = notesStore.delete(id);

  if (!deleted) {
    return jsonResponse({ error: "Note not found" }, 404);
  }

  return jsonResponse(
    {
      success: true,
      message: "Note deleted successfully",
      id,
    },
    200
  );
}
