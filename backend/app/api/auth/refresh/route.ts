import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { prisma } from "@/lib/prisma";
import { verifyJwt, signAccessToken, createSession } from "@/lib/auth";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function POST(req: NextRequest) {
  let body: any = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }

  const refreshToken = String(
    body.refreshToken ||
      body.token ||
      req.headers.get("x-refresh-token") ||
      req.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ||
      ""
  ).trim();

  if (!refreshToken) {
    return jsonResponse(
      { error: "Missing required parameter 'refreshToken'" },
      400
    );
  }

  const payload = await verifyJwt(refreshToken);
  if (!payload || !payload.sub) {
    return jsonResponse(
      { error: "Invalid or expired refresh token" },
      401
    );
  }

  try {
    if (payload.type === "device") {
      const accessToken = await signAccessToken({
        sub: payload.sub,
        deviceId: payload.deviceId || payload.sub,
        role: "device",
        type: "device",
      });

      await createSession({
        token: accessToken,
        deviceId: payload.deviceId || payload.sub,
        expiresInDays: 7,
      });

      return jsonResponse(
        {
          success: true,
          accessToken,
          refreshToken,
          tokenType: "Bearer",
          expiresIn: 604800,
        },
        200
      );
    }

    const user = await prisma.user.findUnique({
      where: { id: payload.sub },
    });

    if (!user) {
      return jsonResponse(
        { error: "User associated with refresh token no longer exists" },
        401
      );
    }

    const accessToken = await signAccessToken({
      sub: user.id,
      email: user.email,
      role: user.role,
      type: "user",
    });

    await createSession({
      token: accessToken,
      userId: user.id,
      expiresInDays: 7,
    });

    return jsonResponse(
      {
        success: true,
        accessToken,
        refreshToken,
        tokenType: "Bearer",
        expiresIn: 604800,
      },
      200
    );
  } catch (err: any) {
    return jsonResponse(
      { error: "Failed to refresh token", details: err.message },
      500
    );
  }
}
