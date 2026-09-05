import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { prisma } from "@/lib/prisma";
import { hashPassword, signAccessToken, signRefreshToken, createSession } from "@/lib/auth";
import { parseFlexibleRequest, createFlexibleResponse } from "@/lib/crypto-transport";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function POST(req: NextRequest) {
  const parsed = await parseFlexibleRequest<{
    email?: string;
    password?: string;
    name?: string;
  }>(req);

  if (!parsed.success) {
    return jsonResponse({ error: parsed.error }, parsed.status);
  }

  const body = parsed.data || {};
  const isEncrypted = parsed.isEncrypted;

  const email = String(body.email || "").trim().toLowerCase();
  const password = String(body.password || "").trim();
  const name = body.name ? String(body.name).trim() : null;

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!email || !emailRegex.test(email)) {
    return createFlexibleResponse(
      { error: "A valid email address is required" },
      400,
      isEncrypted
    );
  }

  if (!password || password.length < 6) {
    return createFlexibleResponse(
      { error: "Password must be at least 6 characters long" },
      400,
      isEncrypted
    );
  }

  try {
    const existing = await prisma.user.findUnique({
      where: { email },
    });

    if (existing) {
      return createFlexibleResponse(
        { error: "User with this email already exists" },
        409,
        isEncrypted
      );
    }

    const passwordHash = await hashPassword(password);
    const user = await prisma.user.create({
      data: {
        email,
        passwordHash,
        name,
        role: "user",
      },
    });

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
        message: "User registered successfully",
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
          expiresIn: 604800, // 7 days in seconds
        },
      },
      201,
      isEncrypted
    );
  } catch (err: any) {
    return createFlexibleResponse(
      { error: "Failed to create user account", details: err.message },
      500,
      isEncrypted
    );
  }
}
