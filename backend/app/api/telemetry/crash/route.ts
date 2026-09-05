import { NextRequest } from "next/server";
import { handleOptions } from "@/lib/cors";
import { telemetryStore } from "@/lib/telemetry";
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

  const errorMessage =
    body.error || body.message || body.errorMessage || "Unknown application exception";
  const stack = body.stack || body.stackTrace || "";
  const deviceId = body.deviceId || "unknown";
  const appVersion = body.appVersion || "2.3.0";
  const osVersion = body.osVersion || "iOS 18+";
  const breadcrumbs = Array.isArray(body.breadcrumbs) ? body.breadcrumbs : [];

  const record = await telemetryStore.record({
    type: "crash",
    name: String(errorMessage).substring(0, 80),
    payload: {
      errorMessage,
      stack,
      breadcrumbs,
      clientTimestamp: body.timestamp || new Date().toISOString(),
    },
    deviceId,
    appVersion,
    osVersion,
  });

  return createEncryptedResponse(
    {
      success: true,
      message: "Crash report recorded",
      eventId: record.id,
      timestamp: record.createdAt,
    },
    201
  );
}
