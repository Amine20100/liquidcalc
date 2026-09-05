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
  if (!auth.authenticated) {
    return jsonResponse(
      { error: auth.error || "Authentication required" },
      401
    );
  }

  if (auth.type === "user" && auth.user) {
    const user = await prisma.user.findUnique({
      where: { id: auth.user.id },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        createdAt: true,
        updatedAt: true,
        devices: {
          select: {
            id: true,
            deviceId: true,
            platform: true,
            name: true,
            lastActiveAt: true,
          },
        },
        _count: {
          select: {
            calculations: true,
            notes: true,
            sessions: true,
          },
        },
      },
    });

    return jsonResponse(
      {
        success: true,
        type: "user",
        profile: user || auth.user,
      },
      200
    );
  }

  if (auth.type === "device" && auth.device) {
    return jsonResponse(
      {
        success: true,
        type: "device",
        device: auth.device,
      },
      200
    );
  }

  if (auth.type === "apikey" && auth.apiKey) {
    return jsonResponse(
      {
        success: true,
        type: "apikey",
        apiKey: auth.apiKey,
        user: auth.user,
      },
      200
    );
  }

  return jsonResponse({ error: "Unknown entity" }, 400);
}

export async function PUT(req: NextRequest) {
  const auth = await authenticateRequest(req);
  if (!auth.authenticated || auth.type !== "user" || !auth.user) {
    return jsonResponse(
      { error: "User authentication required to update profile" },
      401
    );
  }

  let body: any = {};
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON request body" }, 400);
  }

  const name = typeof body.name === "string" ? body.name.trim() : undefined;

  try {
    const updated = await prisma.user.update({
      where: { id: auth.user.id },
      data: {
        name: name !== undefined ? name : undefined,
      },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        updatedAt: true,
      },
    });

    return jsonResponse(
      {
        success: true,
        message: "Profile updated successfully",
        user: updated,
      },
      200
    );
  } catch (err: any) {
    return jsonResponse(
      { error: "Failed to update profile", details: err.message },
      500
    );
  }
}
