import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { authenticateRequest } from "@/lib/auth";
import { linkGuestAccount } from "@/lib/subscription";
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
    deviceId?: string;
    email?: string;
    password?: string;
    name?: string;
  }>(req);

  if (!parsed.success) {
    return jsonResponse({ error: parsed.error }, parsed.status);
  }

  const body = parsed.data || {};
  const isEncrypted = parsed.isEncrypted;

  const auth = await authenticateRequest(req);
  const authenticatedUserId =
    auth.authenticated && auth.type === "user" && auth.user ? auth.user.id : undefined;

  const deviceId =
    body.deviceId ||
    (auth.authenticated && auth.type === "device" && auth.device
      ? auth.device.deviceId
      : undefined) ||
    req.headers.get("x-device-token") ||
    undefined;

  if (!deviceId) {
    return createFlexibleResponse(
      {
        error:
          "Missing required parameter 'deviceId' (either in JSON body or x-device-token header)",
      },
      400,
      isEncrypted
    );
  }

  const email = body.email ? String(body.email).trim().toLowerCase() : undefined;
  const password = body.password ? String(body.password).trim() : undefined;
  const name = body.name ? String(body.name).trim() : undefined;

  if (!authenticatedUserId && (!email || !password)) {
    return createFlexibleResponse(
      {
        error:
          "Authentication credentials required: provide email and password, or valid Authorization Bearer token",
      },
      400,
      isEncrypted
    );
  }

  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return createFlexibleResponse({ error: "A valid email address is required" }, 400, isEncrypted);
  }

  if (password && password.length < 6) {
    return createFlexibleResponse(
      { error: "Password must be at least 6 characters long" },
      400,
      isEncrypted
    );
  }

  try {
    const result = await linkGuestAccount({
      deviceId,
      email,
      password,
      name,
      authenticatedUserId,
    });

    return createFlexibleResponse(result, 200, isEncrypted);
  } catch (err: any) {
    const status = err.message.includes("Invalid password") ? 401 : 400;
    return createFlexibleResponse(
      { error: "Failed to link guest account", details: err.message },
      status,
      isEncrypted
    );
  }
}
