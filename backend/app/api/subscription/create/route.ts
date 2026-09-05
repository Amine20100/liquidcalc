import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { authenticateRequest } from "@/lib/auth";
import { createSubscription } from "@/lib/subscription";
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
    userId?: string;
    deviceId?: string;
    planId?: string;
    tier?: string;
    billingPeriod?: string;
    provider?: string;
    receipt?: string;
    providerSubId?: string;
  }>(req);

  if (!parsed.success) {
    return jsonResponse({ error: parsed.error }, parsed.status);
  }

  const body = parsed.data || {};
  const isEncrypted = parsed.isEncrypted;

  const auth = await authenticateRequest(req);
  const userId =
    auth.authenticated && auth.type === "user" && auth.user ? auth.user.id : body.userId;
  const deviceId =
    body.deviceId ||
    (auth.authenticated && auth.type === "device" && auth.device ? auth.device.deviceId : undefined) ||
    req.headers.get("x-device-token") ||
    undefined;

  if (!userId && !deviceId) {
    return createFlexibleResponse(
      {
        error:
          "Authentication required: Provide Authorization header or x-device-token header or body deviceId",
      },
      401,
      isEncrypted
    );
  }

  try {
    const result = await createSubscription({
      userId,
      deviceId,
      planId: body.planId,
      tier: body.tier,
      billingPeriod: body.billingPeriod,
      provider: body.provider || "mock",
      receipt: body.receipt,
      providerSubId: body.providerSubId,
    });

    return createFlexibleResponse(
      {
        success: true,
        message: `Subscription created successfully for tier ${result.effectiveTier}`,
        subscription: result.subscription,
        entitlements: result.entitlements,
      },
      201,
      isEncrypted
    );
  } catch (err: any) {
    return createFlexibleResponse(
      { error: "Failed to create subscription", details: err.message },
      500,
      isEncrypted
    );
  }
}
