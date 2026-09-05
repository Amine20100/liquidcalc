import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { processStripeWebhook } from "@/lib/subscription";

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

  let event: any = {};
  try {
    event = JSON.parse(rawText);
  } catch {
    return jsonResponse({ error: "Invalid JSON webhook payload" }, 400);
  }

  const result = await processStripeWebhook(event, rawText);

  return jsonResponse(
    {
      received: true,
      provider: "stripe",
      eventType: event?.type,
      webhookId: result.webhookId,
    },
    200
  );
}
