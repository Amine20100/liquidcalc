import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { verifyAdminRequest } from "@/lib/admin";
import {
  getPersistedGeminiApiKey,
  savePersistedGeminiApiKey,
  setRuntimeGeminiApiKey,
  maskApiKey,
} from "@/lib/gemini-key-store";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

/**
 * GET /api/admin/apikey
 * Returns the masked status of the currently active Gemini API key.
 */
export async function GET(req: NextRequest) {
  const auth = await verifyAdminRequest(req);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.error }, auth.status);
  }

  try {
    const key = await getPersistedGeminiApiKey();
    const hasKey = Boolean(key && key.trim().length > 0);
    const source = hasKey
      ? (process.env.GEMINI_API_KEY && key === process.env.GEMINI_API_KEY.trim() ? "env" : "database")
      : "none";

    return jsonResponse({
      success: true,
      hasKey,
      maskedKey: maskApiKey(key),
      source,
      defaultModel: "gemini-2.5-flash",
    }, 200);
  } catch (err: any) {
    return jsonResponse({ error: err.message || "Failed to inspect API key" }, 500);
  }
}

/**
 * POST /api/admin/apikey
 * Securely updates and persists the Gemini API key in the admin control center.
 */
export async function POST(req: NextRequest) {
  const auth = await verifyAdminRequest(req);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.error }, auth.status);
  }

  try {
    const body = await req.json().catch(() => ({}));
    const newKey = String(body.apiKey || "").trim();

    if (!newKey) {
      return jsonResponse({ error: "API Key cannot be empty" }, 400);
    }

    if (!newKey.startsWith("AIzaSy") && newKey.length < 20) {
      return jsonResponse({ error: "Invalid Google Gemini API key format (expected AIzaSy...)" }, 400);
    }

    // Persist to database and update runtime memory
    await savePersistedGeminiApiKey(newKey);
    setRuntimeGeminiApiKey(newKey);

    return jsonResponse({
      success: true,
      message: "Gemini API key updated and persisted successfully",
      maskedKey: maskApiKey(newKey),
      defaultModel: "gemini-2.5-flash",
    }, 200);
  } catch (err: any) {
    return jsonResponse({ error: err.message || "Failed to save API key" }, 500);
  }
}

/**
 * DELETE /api/admin/apikey
 * Removes the configured Gemini API key.
 */
export async function DELETE(req: NextRequest) {
  const auth = await verifyAdminRequest(req);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.error }, auth.status);
  }

  try {
    await savePersistedGeminiApiKey("");
    setRuntimeGeminiApiKey("");

    return jsonResponse({
      success: true,
      message: "Gemini API key removed from runtime memory and database",
      hasKey: false,
    }, 200);
  } catch (err: any) {
    return jsonResponse({ error: err.message || "Failed to delete API key" }, 500);
  }
}
