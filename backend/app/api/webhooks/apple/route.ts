import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { processAppleWebhook } from "@/lib/subscription";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function POST(req: NextRequest | Request) {
  let rawText = "";
  try {
    rawText = await req.text();
  } catch {
    return jsonResponse({ error: "Failed to read webhook payload" }, 400);
  }

  let notification: any = {};
  try {
    notification = JSON.parse(rawText);
  } catch {
    return jsonResponse({ error: "Invalid JSON webhook payload" }, 400);
  }

  const result = await processAppleWebhook(notification, rawText);

  return jsonResponse(
    {
      received: true,
      provider: "apple_storekit",
      notificationType: notification?.notificationType || notification?.type,
      webhookId: result.webhookId,
    },
    200
  );
}
