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

  const rawType = String(body.type || "usage").toLowerCase();
  const validTypes = ["crash", "performance", "calculation", "usage"];
  const type = (validTypes.includes(rawType) ? rawType : "usage") as
    | "crash"
    | "performance"
    | "calculation"
    | "usage";

  const name = body.name || body.eventName || "event";
  const payload = body.payload || body.data || {};
  const deviceId = body.deviceId || "unknown";
  const appVersion = body.appVersion || "2.3.0";
  const osVersion = body.osVersion || undefined;

  const record = await telemetryStore.record({
    type,
    name: String(name),
    payload,
    deviceId,
    appVersion,
    osVersion,
  });

  return createEncryptedResponse(
    {
      success: true,
      message: "Telemetry event recorded",
      eventId: record.id,
      timestamp: record.createdAt,
    },
    201
  );
}
