import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { notesStore } from "@/lib/notes";
import { authenticateRequest } from "@/lib/auth";
import { checkCloudSyncQuota } from "@/lib/subscription";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function GET(req: NextRequest) {
  const searchParams = req.nextUrl.searchParams;
  const auth = await authenticateRequest(req);

  const tag = searchParams.get("tag") || undefined;
  const deviceId =
    searchParams.get("deviceId") ||
    (auth.authenticated && auth.type === "device" && auth.device ? auth.device.deviceId : undefined);
  const userId =
    searchParams.get("userId") ||
    (auth.authenticated && auth.type === "user" && auth.user ? auth.user.id : undefined);
  const search = searchParams.get("search") || searchParams.get("q") || undefined;
  const limit = searchParams.get("limit") ? parseInt(searchParams.get("limit")!, 10) : 20;
  const offset = searchParams.get("offset") ? parseInt(searchParams.get("offset")!, 10) : 0;

  const result = notesStore.list({
    tag,
    deviceId,
    userId,
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

export async function POST(req: NextRequest) {
  let body: any = {};
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON request body" }, 400);
  }

  const title = typeof body.title === "string" ? body.title.trim() : "Untitled note";
  const markdown = typeof body.markdown === "string" ? body.markdown : "";
  const tags = Array.isArray(body.tags) ? body.tags : ["study"];
  const attachments = Array.isArray(body.attachments) ? body.attachments : [];

  const auth = await authenticateRequest(req);
  const userId =
    body.userId ||
    (auth.authenticated && auth.type === "user" && auth.user ? auth.user.id : undefined);
  const deviceId =
    (typeof body.deviceId === "string" && body.deviceId.trim()) ||
    (auth.authenticated && auth.type === "device" && auth.device ? auth.device.deviceId : undefined) ||
    "unknown";

  const id = body.id || `note_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;

  // Enforce tier quota if new note
  const existing = notesStore.get(id);
  if (!existing) {
    const quota = await checkCloudSyncQuota({
      userId,
      deviceId,
      incomingCount: 1,
    });
    if (!quota.allowed) {
      return jsonResponse(
        {
          error: quota.error,
          code: "SYNC_QUOTA_EXCEEDED",
          tier: quota.tier,
          quotaLimit: quota.maxAllowed,
          currentUsage: quota.currentCount,
          upgradeRequired: true,
        },
        403
      );
    }
  }

  const now = new Date().toISOString();

  const syncRes = await notesStore.sync(
    [
      {
        id,
        title,
        markdown,
        tags,
        attachments,
        deviceId,
        userId,
        createdAt: now,
        updatedAt: now,
      },
    ],
    deviceId,
    undefined,
    userId
  );

  const created = notesStore.get(id);

  return jsonResponse(
    {
      success: true,
      message: "Note created successfully",
      note: created,
      totalRecords: syncRes.totalRecords,
    },
    201
  );
}
