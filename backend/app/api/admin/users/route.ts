import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import {
  verifyAdminRequest,
  listAdminUsers,
  upgradeAdminTier,
  toggleAdminUserStatus,
} from "@/lib/admin";
import { revokeAllUserSessions, revokeAllDeviceSessions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

/**
 * GET /api/admin/users
 * Search, filter and paginate registered users and guest device identities.
 */
export async function GET(req: NextRequest) {
  const auth = await verifyAdminRequest(req);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.error }, auth.status);
  }

  const { searchParams } = req.nextUrl;
  const search = searchParams.get("search") || undefined;
  const tier = searchParams.get("tier") || undefined;
  const role = searchParams.get("role") || undefined;
  const status = searchParams.get("status") || undefined;
  const page = searchParams.get("page") ? parseInt(searchParams.get("page")!, 10) : 1;
  const limit = searchParams.get("limit") ? parseInt(searchParams.get("limit")!, 10) : 20;

  try {
    const result = await listAdminUsers({
      search,
      tier,
      role,
      status,
      page,
      limit,
    });
    return jsonResponse(result, 200);
  } catch (err: any) {
    return jsonResponse({ error: "Failed to list users", details: err.message }, 500);
  }
}

/**
 * PATCH /api/admin/users
 * 1-tap tier upgrade, ban/activate status toggle, or session revocation.
 */
export async function PATCH(req: NextRequest) {
  const auth = await verifyAdminRequest(req);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.error }, auth.status);
  }

  let body: any = {};
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const { userId, deviceId, action, tier, status, role, revokeSessions } = body;

  try {
    // Check if this is an explicit single-purpose action without multi-field update
    if (action === "revoke_sessions") {
      let revokedCount = 0;
      if (userId) {
        revokedCount = await revokeAllUserSessions(userId);
      } else if (deviceId) {
        revokedCount = await revokeAllDeviceSessions(deviceId);
      } else {
        return jsonResponse({ error: "Must provide userId or deviceId to revoke sessions" }, 400);
      }

      return jsonResponse(
        {
          success: true,
          message: `Revoked ${revokedCount} active session(s)`,
          revokedCount,
        },
        200
      );
    }

    // Unified / multi-property user update (handles tier, status, and role in one request)
    const updates: Record<string, any> = {};
    let tierResult: any = null;
    let statusResult: any = null;
    let roleResult: any = null;
    let revokedCount = 0;

    // 1. Tier upgrade / modification
    if (tier || action === "upgrade_tier") {
      const targetTier = (tier || body.newTier || "PRO").toUpperCase();
      tierResult = await upgradeAdminTier({
        userId,
        deviceId,
        tier: targetTier,
      });
      updates.tier = targetTier;
      updates.subscription = tierResult.subscription;
    }

    // 2. Status toggle (active / banned)
    if (status !== undefined || action === "toggle_status") {
      if (!userId) {
        return jsonResponse({ error: "userId required to toggle user status" }, 400);
      }
      const targetStatus = status === "banned" || body.banned ? "banned" : "active";
      statusResult = await toggleAdminUserStatus({
        userId,
        status: targetStatus,
      });
      updates.status = targetStatus;
      updates.revokedSessions = statusResult.revokedSessions;
    }

    // 3. Role update (user <-> admin)
    if (role || action === "update_role") {
      if (!userId) {
        return jsonResponse({ error: "userId required to update role" }, 400);
      }
      const updatedUser = await prisma.user.update({
        where: { id: userId },
        data: { role, updatedAt: new Date() },
        select: { id: true, email: true, name: true, role: true },
      });
      roleResult = updatedUser;
      updates.role = role;
    }

    // 4. Explicit session revocation if requested alongside update
    if (revokeSessions) {
      if (userId) {
        revokedCount = await revokeAllUserSessions(userId);
      } else if (deviceId) {
        revokedCount = await revokeAllDeviceSessions(deviceId);
      }
      updates.revokedCount = revokedCount;
    }

    if (Object.keys(updates).length > 0) {
      return jsonResponse(
        {
          success: true,
          message: "User properties updated successfully",
          userId,
          deviceId,
          user: statusResult?.user || roleResult || undefined,
          status: updates.status || statusResult?.status,
          revokedSessions: statusResult?.revokedSessions || updates.revokedSessions || 0,
          tier: updates.tier || tierResult?.tier,
          entitlements: tierResult?.entitlements,
          subscription: tierResult?.subscription,
          updates,
          tierResult,
          statusResult,
          roleResult,
        },
        200
      );
    }

    return jsonResponse(
      {
        error: "Unrecognized admin action or missing fields. Supported: tier, status, role, action: upgrade_tier, toggle_status, revoke_sessions, update_role",
      },
      400
    );
  } catch (err: any) {
    return jsonResponse({ error: err.message || "Failed to execute user update" }, 500);
  }
}

/**
 * DELETE /api/admin/users
 * Delete a user or guest device.
 */
export async function DELETE(req: NextRequest) {
  const auth = await verifyAdminRequest(req);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.error }, auth.status);
  }

  const { searchParams } = req.nextUrl;
  let userId = searchParams.get("userId");
  let deviceId = searchParams.get("deviceId");

  if (!userId && !deviceId) {
    try {
      const body = await req.json();
      userId = body.userId;
      deviceId = body.deviceId;
    } catch {}
  }

  if (!userId && !deviceId) {
    return jsonResponse({ error: "Must specify userId or deviceId to delete" }, 400);
  }

  try {
    if (userId) {
      const user = await prisma.user.findUnique({ where: { id: userId } });
      if (!user) {
        return jsonResponse({ error: "User not found" }, 404);
      }
      await prisma.user.delete({ where: { id: userId } });
      return jsonResponse({ success: true, message: "User account deleted successfully", userId }, 200);
    } else if (deviceId) {
      const dev = await prisma.deviceToken.findFirst({
        where: {
          OR: [{ deviceId }, { id: deviceId }],
        },
      });
      if (!dev) {
        return jsonResponse({ error: "Device not found" }, 404);
      }
      await prisma.session.deleteMany({
        where: { OR: [{ deviceId: dev.id }, { deviceId: dev.deviceId }] },
      });
      await prisma.deviceToken.delete({ where: { id: dev.id } });
      return jsonResponse({ success: true, message: "Device record deleted successfully", deviceId: dev.deviceId }, 200);
    }
  } catch (err: any) {
    return jsonResponse({ error: "Failed to delete record", details: err.message }, 500);
  }
}

