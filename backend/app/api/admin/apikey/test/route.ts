import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { verifyAdminRequest } from "@/lib/admin";
import { getPersistedGeminiApiKey } from "@/lib/gemini-key-store";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

/**
 * POST /api/admin/apikey/test
 * Tests a Gemini API key against Google Generative Language API (gemini-2.5-flash).
 */
export async function POST(req: NextRequest) {
  const auth = await verifyAdminRequest(req);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.error }, auth.status);
  }

  try {
    const body = await req.json().catch(() => ({}));
    let targetKey = String(body.apiKey || "").trim();

    if (!targetKey) {
      targetKey = await getPersistedGeminiApiKey();
    }

    if (!targetKey) {
      return jsonResponse({
        success: false,
        error: "No Gemini API key provided or currently configured to test",
      }, 400);
    }

    const startTime = Date.now();
    const model = body.model || "gemini-2.5-flash";
    const googleEndpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(targetKey)}`;

    const googleRes = await fetch(googleEndpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        contents: [
          {
            role: "user",
            parts: [{ text: "Respond with the word 'VERIFIED' and nothing else." }],
          },
        ],
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 10,
        },
      }),
    });

    const elapsedMs = Date.now() - startTime;
    const responseData = await googleRes.json().catch(() => ({}));

    if (!googleRes.ok) {
      const errorMsg =
        responseData?.error?.message ||
        responseData?.error?.status ||
        `Google API responded with status ${googleRes.status}`;
      return jsonResponse({
        success: false,
        status: googleRes.status,
        error: errorMsg,
        latencyMs: elapsedMs,
        model,
      }, 200);
    }

    const candidateText =
      responseData?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() || "OK";

    return jsonResponse({
      success: true,
      message: "Gemini API key is active, valid, and responding properly",
      model,
      latencyMs: elapsedMs,
      output: candidateText,
    }, 200);
  } catch (err: any) {
    return jsonResponse({
      success: false,
      error: err.message || "Failed to reach Google Generative Language API",
    }, 500);
  }
}
