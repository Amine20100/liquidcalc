import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { historyStore, HistoryItem } from "@/lib/storage";
import { authenticateRequest } from "@/lib/auth";
import { checkCloudSyncQuota } from "@/lib/subscription";
import {
  decryptAndVerifyRequest,
  createEncryptedResponse,
  cryptoErrorResponse,
} from "@/lib/crypto-transport";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function POST(req: NextRequest) {
  // Enforce strict transport obfuscation & dynamic signature verification
  const decrypted = await decryptAndVerifyRequest<{
    deviceId?: string;
    items?: HistoryItem[];
    since?: string;
  }>(req);

  if (!decrypted.success) {
    return cryptoErrorResponse(decrypted);
  }

  const body = decrypted.data;

  if (!body || typeof body !== "object" || !Array.isArray(body.items)) {
    return jsonResponse(
      { error: "Missing or invalid required field 'items' (must be an array)" },
      { status: 400 }
    );
  }

  const items = body.items;
  const deviceId = body.deviceId || "ios-device";
  const since =
    (typeof body.since === "string" && body.since.trim()) ||
    req.nextUrl.searchParams.get("since") ||
    undefined;

  const auth = await authenticateRequest(req);
  const userId =
    auth.authenticated && auth.type === "user" && auth.user
      ? auth.user.id
      : undefined;

  // Enforce Cloud Sync tier limits for Free vs Pro/Ultra
  const newItems = items.filter((item) => !item.deleted && !historyStore.get(item.id));
  const quota = await checkCloudSyncQuota({
    userId,
    deviceId,
    incomingCount: newItems.length,
  });

  if (!quota.allowed) {
    return createEncryptedResponse(
      {
        success: false,
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

  const result = historyStore.sync(items, deviceId, since, userId);

  return createEncryptedResponse(result, 200);
}
