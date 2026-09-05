import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { authenticateRequest } from "@/lib/auth";
import { getUserOrDeviceSubscription } from "@/lib/subscription";
import { historyStore } from "@/lib/storage";
import { notesStore } from "@/lib/notes";
import { prisma } from "@/lib/prisma";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function GET(req: NextRequest) {
  const searchParams = req.nextUrl.searchParams;
  const auth = await authenticateRequest(req);

  const queryUserId = searchParams.get("userId") || undefined;
  const queryDeviceId =
    searchParams.get("deviceId") ||
    req.headers.get("x-device-token") ||
    undefined;

  const userId =
    auth.authenticated && auth.type === "user" && auth.user
      ? auth.user.id
      : queryUserId;
  const deviceId =
    auth.authenticated && auth.type === "device" && auth.device
      ? auth.device.deviceId
      : queryDeviceId;

  const { tier, subscription, entitlements, isActive } =
    await getUserOrDeviceSubscription({ userId, deviceId });

  const ownerParams = { userId, deviceId };
  const calcCount = historyStore.countForOwner(ownerParams);
  const noteCount = notesStore.countForOwner(ownerParams);
  const totalUsed = calcCount + noteCount;

  const isUnlimited = entitlements.maxCloudSyncItems === -1;
  const remainingQuota = isUnlimited
    ? Infinity
    : Math.max(0, entitlements.maxCloudSyncItems - totalUsed);

  let activeDevices = 1;
  try {
    if (userId) {
      activeDevices = await prisma.deviceToken.count({ where: { userId } });
    }
  } catch {}

  return jsonResponse({
    success: true,
    tier,
    status: subscription ? subscription.status : "free",
    isActiveSubscription: isActive,
    subscription,
    entitlements,
    cloudSyncUsage: {
      usedCalculations: calcCount,
      usedNotes: noteCount,
      totalUsedItems: totalUsed,
      maxAllowedItems: entitlements.maxCloudSyncItems,
      isUnlimited,
      remainingQuota: isUnlimited ? -1 : remainingQuota,
    },
    devicesUsage: {
      activeDevices: Math.max(1, activeDevices),
      maxDevices: entitlements.maxDevices,
      isUnlimited: entitlements.maxDevices === -1,
    },
  });
}
