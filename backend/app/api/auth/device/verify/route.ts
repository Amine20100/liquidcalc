import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { prisma } from "@/lib/prisma";
import { verifyJwt } from "@/lib/auth";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

async function handleVerification(token: string | null) {
  if (!token) {
    return jsonResponse(
      { valid: false, error: "Missing device token" },
      400
    );
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

    return jsonResponse(
      {
        valid: true,
        deviceId: verified.deviceId,
        role: "device",
      },
      200
    );
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

      return jsonResponse(
        {
          valid: true,
          deviceId: device.deviceId,
          platform: device.platform,
          name: device.name,
          user: device.user,
        },
        200
      );
    }
  } catch {
    // Ignore
  }

  return jsonResponse(
    { valid: false, error: "Invalid or unverified device token" },
    401
  );
}

export async function GET(req: NextRequest) {
  const token =
    req.headers.get("x-device-token") ||
    req.nextUrl.searchParams.get("token") ||
    req.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ||
    null;

  return handleVerification(token);
}

export async function POST(req: NextRequest) {
  let body: any = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }

  const token =
    body.token ||
    req.headers.get("x-device-token") ||
    req.nextUrl.searchParams.get("token") ||
    req.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ||
    null;

  return handleVerification(token);
}
