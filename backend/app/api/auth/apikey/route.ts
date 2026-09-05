import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { prisma } from "@/lib/prisma";
import { authenticateRequest } from "@/lib/auth";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function GET(req: NextRequest) {
  const auth = await authenticateRequest(req);
  if (!auth.authenticated || auth.type !== "user" || !auth.user) {
    return jsonResponse(
      { error: "Authentication required to list API keys" },
      401
    );
  }

  try {
    const keys = await prisma.apiKey.findMany({
      where: { userId: auth.user.id },
      select: {
        id: true,
        name: true,
        key: true,
        active: true,
        createdAt: true,
      },
      orderBy: { createdAt: "desc" },
    });

    return jsonResponse({ success: true, keys }, 200);
  } catch (err: any) {
    return jsonResponse({ error: "Failed to list API keys", details: err.message }, 500);
  }
}

export async function POST(req: NextRequest) {
  const auth = await authenticateRequest(req);
  let body: any = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }

  const name = typeof body.name === "string" && body.name.trim() ? body.name.trim() : "Default Key";
  const rawRandom = Math.random().toString(36).substring(2, 12) + Math.random().toString(36).substring(2, 12);
  const key = `lqc_live_${rawRandom}`;

  try {
    const apiKey = await prisma.apiKey.create({
      data: {
        key,
        name,
        userId: auth.type === "user" && auth.user ? auth.user.id : undefined,
        active: true,
      },
    });

    return jsonResponse(
      {
        success: true,
        message: "API key generated successfully",
        apiKey: {
          id: apiKey.id,
          key: apiKey.key,
          name: apiKey.name,
          createdAt: apiKey.createdAt,
        },
      },
      201
    );
  } catch (err: any) {
    return jsonResponse({ error: "Failed to create API key", details: err.message }, 500);
  }
}
