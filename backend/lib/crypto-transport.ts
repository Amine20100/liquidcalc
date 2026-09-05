import crypto from "crypto";
import { NextRequest, NextResponse } from "next/server";
import { CORS_HEADERS, jsonResponse } from "@/lib/cors";

/**
 * Shared root secret seed for transport obfuscation.
 * Can be overridden via environment variables in production.
 */
export const MASTER_SECRET =
  process.env.LIQUIDCALC_TRANSPORT_SECRET ||
  "liqidcalc_sec_transport_v2_2026_gcm_hmac_secret_payload_key";

/**
 * Deterministically derived 256-bit AES-GCM encryption key.
 */
export const ENC_KEY = crypto
  .createHash("sha256")
  .update(MASTER_SECRET + ":aes256_enc")
  .digest();

/**
 * Deterministically derived 256-bit HMAC-SHA256 signing key.
 */
export const HMAC_KEY = crypto
  .createHash("sha256")
  .update(MASTER_SECRET + ":hmac_sha256")
  .digest();

/**
 * Timestamp freshness tolerance window in milliseconds (5 minutes).
 */
export const TIMESTAMP_TOLERANCE_MS = 300_000;

export interface DecryptedSuccess<T = any> {
  success: true;
  data: T;
  rawText: string;
  timestamp: number;
  nonce: string;
}

export interface DecryptedFailure {
  success: false;
  status: number;
  error: string;
}

export type DecryptedResult<T = any> = DecryptedSuccess<T> | DecryptedFailure;

/**
 * Converts a Base64URL string to a Buffer safely.
 */
export function base64urlToBuffer(base64url: string): Buffer {
  try {
    return Buffer.from(base64url, "base64url");
  } catch {
    let b64 = base64url.replace(/-/g, "+").replace(/_/g, "/");
    while (b64.length % 4) b64 += "=";
    return Buffer.from(b64, "base64");
  }
}

/**
 * Converts a Buffer to a Base64URL string.
 */
export function bufferToBase64url(buf: Buffer): string {
  return buf.toString("base64url");
}

/**
 * Constant-time comparison between two hex strings to avoid timing leaks.
 */
export function safeCompareHex(a: string, b: string): boolean {
  if (typeof a !== "string" || typeof b !== "string") return false;
  const bufA = Buffer.from(a.toLowerCase(), "hex");
  const bufB = Buffer.from(b.toLowerCase(), "hex");
  if (bufA.length === 0 || bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

/**
 * Signs a payload with HMAC-SHA256 using the derived HMAC_KEY.
 */
export function signPayload(timestamp: string, nonce: string, bodyString: string): string {
  return crypto
    .createHmac("sha256", HMAC_KEY)
    .update(`${timestamp}:${nonce}:${bodyString}`)
    .digest("hex");
}

/**
 * Encrypts arbitrary data with AES-256-GCM + Base64URL entropy masking and signs it.
 */
export function encryptPayload(data: any): {
  payload: string;
  timestamp: string;
  nonce: string;
  signature: string;
} {
  const plaintext = typeof data === "string" ? data : JSON.stringify(data);
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", ENC_KEY, iv);
  const ciphertext = Buffer.concat([cipher.update(plaintext, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  const combined = Buffer.concat([iv, ciphertext, tag]);
  const payload = bufferToBase64url(combined);

  const timestamp = Math.floor(Date.now() / 1000).toString();
  const nonce = crypto.randomBytes(16).toString("hex");
  const signature = signPayload(timestamp, nonce, payload);

  return { payload, timestamp, nonce, signature };
}

/**
 * Decrypts a Base64URL AES-256-GCM ciphertext payload.
 */
export function decryptPayload<T = any>(cipherStr: string): T {
  const cleanStr = cipherStr.trim();
  const combined = base64urlToBuffer(cleanStr);
  if (combined.length < 28) {
    throw new Error("Ciphertext too short (must contain 12-byte IV + 16-byte GCM tag)");
  }

  const iv = combined.subarray(0, 12);
  const tag = combined.subarray(combined.length - 16);
  const ciphertext = combined.subarray(12, combined.length - 16);

  const decipher = crypto.createDecipheriv("aes-256-gcm", ENC_KEY, iv);
  decipher.setAuthTag(tag);
  const decrypted = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
  const utf8 = decrypted.toString("utf8");

  try {
    return JSON.parse(utf8);
  } catch {
    return utf8 as unknown as T;
  }
}

/**
 * Middleware helper to decrypt and verify incoming NextRequest or standard Request.
 * Strictly enforces signature, timestamp window, and AES-GCM decryption.
 */
export async function decryptAndVerifyRequest<T = any>(
  req: NextRequest | Request
): Promise<DecryptedResult<T>> {
  const signature =
    req.headers.get("x-signature") || req.headers.get("X-Signature");
  const timestamp =
    req.headers.get("x-timestamp") || req.headers.get("X-Timestamp");
  const nonce =
    req.headers.get("x-nonce") || req.headers.get("X-Nonce");

  if (!signature || !timestamp || !nonce) {
    return {
      success: false,
      status: 403,
      error:
        "Forbidden: Missing required transport security headers (X-Signature, X-Timestamp, X-Nonce)",
    };
  }

  // Validate timestamp freshness (supports seconds or milliseconds)
  const tsNum = Number(timestamp);
  if (isNaN(tsNum)) {
    return {
      success: false,
      status: 403,
      error: "Forbidden: Invalid timestamp format in X-Timestamp",
    };
  }

  const tsMs = tsNum < 1e11 ? tsNum * 1000 : tsNum;
  const now = Date.now();
  if (Math.abs(now - tsMs) > TIMESTAMP_TOLERANCE_MS) {
    return {
      success: false,
      status: 403,
      error: "Forbidden: Request timestamp expired or outside tolerance window",
    };
  }

  // Read raw body
  let rawBody = "";
  try {
    rawBody = await req.text();
  } catch (err: any) {
    return {
      success: false,
      status: 400,
      error: `Bad Request: Failed to read request body: ${err.message}`,
    };
  }

  if (!rawBody || rawBody.trim().length === 0) {
    return {
      success: false,
      status: 400,
      error: "Bad Request: Empty request body",
    };
  }

  // Verify HMAC signature over (timestamp:nonce:rawBody)
  const expectedSignature = signPayload(timestamp, nonce, rawBody);
  if (!safeCompareHex(signature, expectedSignature)) {
    return {
      success: false,
      status: 403,
      error: "Forbidden: Invalid transport signature",
    };
  }

  // Extract base64url ciphertext string
  let cipherStr = rawBody.trim();
  if (cipherStr.startsWith("{")) {
    try {
      const parsed = JSON.parse(cipherStr);
      if (typeof parsed.data === "string") {
        cipherStr = parsed.data.trim();
      } else if (typeof parsed.payload === "string") {
        cipherStr = parsed.payload.trim();
      } else {
        // Plain JSON object without encrypted data
        return {
          success: false,
          status: 403,
          error:
            "Forbidden: Plain JSON payload rejected on obfuscated endpoint",
        };
      }
    } catch {
      return {
        success: false,
        status: 400,
        error: "Bad Request: Malformed JSON envelope",
      };
    }
  }

  // Decrypt AES-256-GCM payload
  try {
    const data = decryptPayload<T>(cipherStr);
    return {
      success: true,
      data,
      rawText: typeof data === "string" ? data : JSON.stringify(data),
      timestamp: tsMs,
      nonce,
    };
  } catch (err: any) {
    return {
      success: false,
      status: 403,
      error: `Forbidden: Transport payload decryption failed: ${err.message}`,
    };
  }
}

/**
 * Returns a standardized error response for transport failures.
 */
export function cryptoErrorResponse(
  result: DecryptedFailure,
  additionalHeaders: Record<string, string> = {}
): NextResponse {
  return jsonResponse(
    {
      error: result.error,
      code: "TRANSPORT_SECURITY_ERROR",
    },
    {
      status: result.status,
      headers: additionalHeaders,
    }
  );
}

/**
 * Helper for endpoints that support both encrypted transport payloads and plain JSON payloads.
 */
export async function parseFlexibleRequest<T = any>(
  req: NextRequest | Request
): Promise<
  | { success: true; data: T; isEncrypted: boolean }
  | { success: false; status: number; error: string }
> {
  const hasCryptoHeaders = Boolean(
    req.headers.get("x-signature") || req.headers.get("X-Signature")
  );
  const contentType = req.headers.get("content-type") || "";
  const isOctetStream = contentType.includes("application/octet-stream");

  if (hasCryptoHeaders || isOctetStream) {
    const dec = await decryptAndVerifyRequest<T>(req);
    if (!dec.success) {
      return dec;
    }
    return { success: true, data: dec.data, isEncrypted: true };
  }

  try {
    const data = await req.json();
    return { success: true, data, isEncrypted: false };
  } catch (err: any) {
    return {
      success: false,
      status: 400,
      error: `Invalid JSON request body: ${err.message}`,
    };
  }
}

/**
 * Returns either an encrypted response or a JSON response based on whether the request was encrypted.
 */
export function createFlexibleResponse(
  data: any,
  status = 200,
  isEncrypted = false,
  additionalHeaders: Record<string, string> = {}
): NextResponse {
  if (isEncrypted) {
    return createEncryptedResponse(data, status, additionalHeaders);
  }
  return jsonResponse(data, { status, headers: additionalHeaders });
}

/**
 * Creates an obfuscated, AES-256-GCM encrypted and signed HTTP response.
 */
export function createEncryptedResponse(
  data: any,
  status = 200,
  additionalHeaders: Record<string, string> = {}
): NextResponse {
  const { payload, timestamp, nonce, signature } = encryptPayload(data);

  const headers = new Headers();
  Object.entries(CORS_HEADERS).forEach(([k, v]) => headers.set(k, v));
  Object.entries(additionalHeaders).forEach(([k, v]) => headers.set(k, v));

  headers.set("Content-Type", "application/octet-stream");
  headers.set("X-Signature", signature);
  headers.set("X-Timestamp", timestamp);
  headers.set("X-Nonce", nonce);
  headers.set("X-Encrypted", "1");

  return new NextResponse(payload, {
    status,
    headers,
  });
}

/**
 * Encrypts an individual SSE streaming chunk.
 */
export function encryptStreamChunk(text: string, done: boolean): string {
  const plaintext = JSON.stringify({ text, done });
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", ENC_KEY, iv);
  const ciphertext = Buffer.concat([cipher.update(plaintext, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  const combined = Buffer.concat([iv, ciphertext, tag]);
  return bufferToBase64url(combined);
}

/**
 * Decrypts an individual SSE streaming chunk.
 */
export function decryptStreamChunk(chunkBase64Url: string): { text: string; done: boolean } {
  const combined = base64urlToBuffer(chunkBase64Url.trim());
  if (combined.length < 28) {
    throw new Error("Invalid chunk length");
  }
  const iv = combined.subarray(0, 12);
  const tag = combined.subarray(combined.length - 16);
  const ciphertext = combined.subarray(12, combined.length - 16);

  const decipher = crypto.createDecipheriv("aes-256-gcm", ENC_KEY, iv);
  decipher.setAuthTag(tag);
  const decrypted = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
  return JSON.parse(decrypted.toString("utf8"));
}
