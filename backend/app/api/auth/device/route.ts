import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { issueDeviceToken, authenticateRequest, createSession } from "@/lib/auth";
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
  const decrypted = await decryptAndVerifyRequest<any>(req);
  if (!decrypted.success) {
    return cryptoErrorResponse(decrypted);
  }

  const body = decrypted.data || {};

  // Device ID can be provided or auto-generated for initial device bootstrap
  const deviceId =
    (typeof body.deviceId === "string" && body.deviceId.trim()) ||
    `ios_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  const platform = typeof body.platform === "string" ? body.platform : "ios";
  const name = typeof body.name === "string" ? body.name : "LiquidCalc Mobile Client";

  // Optionally associate with user if user is logged in
  const auth = await authenticateRequest(req);
  const userId = auth.type === "user" && auth.user ? auth.user.id : undefined;

  try {
    const { token, device } = await issueDeviceToken({
      deviceId,
      platform,
      name,
      userId,
    });

    await createSession({
      token,
      deviceId: device.id,
      userId,
      expiresInDays: 365,
    });

    return createEncryptedResponse(
      {
        success: true,
        message: "Mobile device token issued successfully",
        deviceToken: token,
        device: {
          id: device.id,
          deviceId: device.deviceId,
          platform: device.platform,
          name: device.name,
          lastActiveAt: device.lastActiveAt,
        },
      },
      200
    );
  } catch (err: any) {
    return createEncryptedResponse(
      { error: "Failed to issue device token", details: err.message },
      500
    );
  }
}
