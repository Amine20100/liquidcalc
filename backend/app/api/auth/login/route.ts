import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { prisma } from "@/lib/prisma";
import { comparePassword, signAccessToken, signRefreshToken, createSession } from "@/lib/auth";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function POST(req: NextRequest) {
  let body: any = {};
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON request body" }, 400);
  }

  const email = String(body.email || "").trim().toLowerCase();
  const password = String(body.password || "").trim();

  if (!email || !password) {
    return jsonResponse(
      { error: "Email and password are required" },
      400
    );
  }

  try {
    const user = await prisma.user.findUnique({
      where: { email },
    });

    if (!user) {
      return jsonResponse(
        { error: "Invalid email or password" },
        401
      );
    }

    const matches = await comparePassword(password, user.passwordHash);
    if (!matches) {
      return jsonResponse(
        { error: "Invalid email or password" },
        401
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

    return jsonResponse(
      {
        success: true,
        message: "Login successful",
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role,
          createdAt: user.createdAt,
        },
        tokens: {
          accessToken,
          refreshToken,
          tokenType: "Bearer",
          expiresIn: 604800,
        },
      },
      200
    );
  } catch (err: any) {
    return jsonResponse(
      { error: "Authentication failed", details: err.message },
      500
    );
  }
}
