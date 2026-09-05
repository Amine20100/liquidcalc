import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { authenticateRequest } from "@/lib/auth";
import { redeemPromoCode } from "@/lib/subscription";
import {
  parseFlexibleRequest,
  createFlexibleResponse,
} from "@/lib/crypto-transport";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function POST(req: NextRequest) {
  const parsed = await parseFlexibleRequest<{
    code?: string;
    userId?: string;
    deviceId?: string;
  }>(req);

  if (!parsed.success) {
    return jsonResponse({ error: parsed.error }, parsed.status);
  }

  const body = parsed.data || {};
  const isEncrypted = parsed.isEncrypted;

  const code = String(body.code || "").trim();
  if (!code) {
    return createFlexibleResponse({ error: "Missing required parameter 'code'" }, 400, isEncrypted);
  }

  const auth = await authenticateRequest(req);
  const userId =
    auth.authenticated && auth.type === "user" && auth.user ? auth.user.id : body.userId;
  const deviceId =
    body.deviceId ||
    (auth.authenticated && auth.type === "device" && auth.device ? auth.device.deviceId : undefined) ||
    req.headers.get("x-device-token") ||
    undefined;

  try {
    const result = await redeemPromoCode({
      code,
      userId,
      deviceId,
    });

    if (!result.success) {
      return createFlexibleResponse(
        { success: false, error: result.error },
        400,
        isEncrypted
      );
    }

    return createFlexibleResponse(result, 200, isEncrypted);
  } catch (err: any) {
    return createFlexibleResponse(
      { error: "Failed to redeem promo code", details: err.message },
      500,
      isEncrypted
    );
  }
}
