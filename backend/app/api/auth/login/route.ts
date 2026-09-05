import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { prisma } from "@/lib/prisma";
import { comparePassword, signAccessToken, signRefreshToken, createSession } from "@/lib/auth";
import { parseFlexibleRequest, createFlexibleResponse } from "@/lib/crypto-transport";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function POST(req: NextRequest) {
  const parsed = await parseFlexibleRequest<{
    email?: string;
    password?: string;
  }>(req);

  if (!parsed.success) {
    return jsonResponse({ error: parsed.error }, parsed.status);
  }

  const body = parsed.data || {};
  const isEncrypted = parsed.isEncrypted;

  const email = String(body.email || "").trim().toLowerCase();
  const password = String(body.password || "").trim();

  if (!email || !password) {
    return createFlexibleResponse(
      { error: "Email and password are required" },
      400,
      isEncrypted
    );
  }

  try {
    const user = await prisma.user.findUnique({
      where: { email },
    });

    if (!user) {
      return createFlexibleResponse(
        { error: "Invalid email or password" },
        401,
        isEncrypted
      );
    }

    const matches = await comparePassword(password, user.passwordHash);
    if (!matches) {
      return createFlexibleResponse(
        { error: "Invalid email or password" },
        401,
        isEncrypted
      );
    }

    const accessToken = await signAccessToken({
      sub: user.id,
      email: user.email,
      role: user.role,
      type: "user",
    });

    const refreshToken = await signRefreshToken({
      sub: user.id,
      type: "user",
    });

    await createSession({
      token: accessToken,
      userId: user.id,
    });

    return createFlexibleResponse(
      {
        success: true,
        message: "Login successful",
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role,
          tier: (user as any).tier || "FREE",
          createdAt: user.createdAt,
        },
        tokens: {
          accessToken,
          refreshToken,
          tokenType: "Bearer",
          expiresIn: 604800,
        },
      },
      200,
      isEncrypted
    );
  } catch (err: any) {
    return createFlexibleResponse(
      { error: "Authentication failed", details: err.message },
      500,
      isEncrypted
    );
  }
}
