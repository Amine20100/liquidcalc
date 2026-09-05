import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { resolveGeminiApiKey, solveStructured } from "@/lib/gemini";
import {
  decryptAndVerifyRequest,
  createEncryptedResponse,
  cryptoErrorResponse,
} from "@/lib/crypto-transport";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function POST(req: NextRequest) {
  // Enforce strict transport obfuscation & dynamic signature verification
  const decrypted = await decryptAndVerifyRequest<any>(req);
  if (!decrypted.success) {
    return cryptoErrorResponse(decrypted);
  }

  const body = decrypted.data;

  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return jsonResponse({ error: "Invalid JSON payload" }, 400);
  }

  // Validate mode if provided
  if (body.mode && body.mode !== "math" && body.mode !== "receipt") {
    return jsonResponse(
      {
        error: `Invalid mode '${body.mode}'. Supported modes are 'math' or 'receipt'`,
      },
      { status: 400 }
    );
  }

  const hasExpression = Boolean(
    typeof body.expression === "string" && body.expression.trim().length > 0
  );
  const hasPrompt = Boolean(
    typeof body.prompt === "string" && body.prompt.trim().length > 0
  );
  const hasImage = Boolean(
    typeof body.image === "string" && body.image.trim().length > 0
  );

  if (!hasExpression && !hasPrompt && !hasImage) {
    return jsonResponse(
      {
        error:
          "Missing required parameter: 'expression', 'prompt', or 'image' must be provided",
      },
      { status: 400 }
    );
  }

  const apiKey = resolveGeminiApiKey(req);
  const mode = (body.mode === "receipt" ? "receipt" : "math") as
    | "math"
    | "receipt";
  const expression =
    (typeof body.expression === "string" && body.expression.trim()) ||
    (typeof body.prompt === "string" && body.prompt.trim()) ||
    "x^2 + 5x + 6 = 0";

  const result = await solveStructured({
    mode,
    expression,
    prompt: typeof body.prompt === "string" ? body.prompt : undefined,
    image: typeof body.image === "string" ? body.image : undefined,
    apiKey,
    model: typeof body.model === "string" ? body.model : undefined,
  });

  return createEncryptedResponse(result, 200);
}
