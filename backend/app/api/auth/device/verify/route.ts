import { NextRequest } from "next/server";
import { handleOptions } from "@/lib/cors";
import { prisma } from "@/lib/prisma";
import { verifyJwt } from "@/lib/auth";
import {
  decryptAndVerifyRequest,
  createEncryptedResponse,
  cryptoErrorResponse,
  signPayload,
  safeCompareHex,
  TIMESTAMP_TOLERANCE_MS,
} from "@/lib/crypto-transport";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

async function handleVerification(token: string | null): Promise<{ status: number; data: any }> {
  if (!token) {
    return {
      status: 400,
      data: { valid: false, error: "Missing device token" },
    };
  }

  // 1. Verify JWT signature
  const verified = await verifyJwt(token);
  if (verified && verified.type === "device" && verified.deviceId) {
    // Optionally update lastActiveAt in DB
    try {
      await prisma.deviceToken.updateMany({
        where: { deviceId: verified.deviceId },
        data: { lastActiveAt: new Date() },
      });
    } catch {
      // Ignore
    }

    return {
      status: 200,
      data: {
        valid: true,
        deviceId: verified.deviceId,
        role: "device",
      },
    };
  }

  // 2. Check Database record by token or deviceId
  try {
    let device = await prisma.deviceToken.findUnique({
      where: { token },
      include: { user: { select: { id: true, email: true, name: true } } },
    });

    if (!device) {
      device = await prisma.deviceToken.findUnique({
        where: { deviceId: token },
        include: { user: { select: { id: true, email: true, name: true } } },
      });
    }

    if (device) {
      await prisma.deviceToken.update({
        where: { id: device.id },
        data: { lastActiveAt: new Date() },
      });

      return {
        status: 200,
        data: {
          valid: true,
          deviceId: device.deviceId,
          platform: device.platform,
          name: device.name,
          user: device.user,
        },
      };
    }
  } catch {
    // Ignore
  }

  return {
    status: 401,
    data: { valid: false, error: "Invalid or unverified device token" },
  };
}

export async function GET(req: NextRequest) {
  const signature =
    req.headers.get("x-signature") || req.headers.get("X-Signature");
  const timestamp =
    req.headers.get("x-timestamp") || req.headers.get("X-Timestamp");
  const nonce =
    req.headers.get("x-nonce") || req.headers.get("X-Nonce");

  if (!signature || !timestamp || !nonce) {
    return cryptoErrorResponse({
      success: false,
      status: 403,
      error:
        "Forbidden: Missing required transport security headers (X-Signature, X-Timestamp, X-Nonce)",
    });
  }

  const tsNum = Number(timestamp);
  const tsMs = tsNum < 1e11 ? tsNum * 1000 : tsNum;
  if (isNaN(tsNum) || Math.abs(Date.now() - tsMs) > TIMESTAMP_TOLERANCE_MS) {
    return cryptoErrorResponse({
      success: false,
      status: 403,
      error: "Forbidden: Request timestamp expired or outside tolerance window",
    });
  }

  const expectedSig = signPayload(timestamp, nonce, "");
  if (!safeCompareHex(signature, expectedSig)) {
    return cryptoErrorResponse({
      success: false,
      status: 403,
      error: "Forbidden: Invalid transport signature",
    });
  }

  const token =
    req.headers.get("x-device-token") ||
    req.nextUrl.searchParams.get("token") ||
    req.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ||
    null;

  const result = await handleVerification(token);
  return createEncryptedResponse(result.data, result.status);
}

export async function POST(req: NextRequest) {
  // Enforce strict transport obfuscation & dynamic signature verification
  const decrypted = await decryptAndVerifyRequest<any>(req);
  if (!decrypted.success) {
    return cryptoErrorResponse(decrypted);
  }

  const body = decrypted.data || {};
  const token =
    body.token ||
    body.deviceToken ||
    req.headers.get("x-device-token") ||
    req.nextUrl.searchParams.get("token") ||
    req.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ||
    null;

  const result = await handleVerification(token);
  return createEncryptedResponse(result.data, result.status);
}
