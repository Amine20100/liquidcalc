import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { authenticateRequest } from "@/lib/auth";
import { verifySubscriptionReceipt } from "@/lib/subscription";
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
    receipt?: string;
    provider?: string;
    tier?: string;
    billingPeriod?: string;
    planId?: string;
    userId?: string;
    deviceId?: string;
  }>(req);

  if (!parsed.success) {
    return jsonResponse({ error: parsed.error }, parsed.status);
  }

  const body = parsed.data || {};
  const isEncrypted = parsed.isEncrypted;

  const receipt = String(body.receipt || "").trim();
  if (!receipt) {
    return createFlexibleResponse(
      { error: "Missing required parameter 'receipt'" },
      400,
      isEncrypted
    );
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
    const result = await verifySubscriptionReceipt({
      receipt,
      provider: body.provider,
      tier: body.tier,
      billingPeriod: body.billingPeriod,
      planId: body.planId,
      userId,
      deviceId,
    });

    if (!result.valid) {
      return createFlexibleResponse(
        { valid: false, error: result.error || "Subscription verification failed" },
        400,
        isEncrypted
      );
    }

    return createFlexibleResponse(
      {
        valid: true,
        message: "Receipt verified and subscription activated successfully",
        tier: result.tier,
        provider: result.provider,
        subscription: result.subscription,
        entitlements: result.entitlements,
      },
      200,
      isEncrypted
    );
  } catch (err: any) {
    return createFlexibleResponse(
      { error: "Internal error verifying subscription", details: err.message },
      500,
      isEncrypted
    );
  }
}
