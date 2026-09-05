import { NextResponse } from "next/server";

export const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS, PATCH",
  "Access-Control-Allow-Headers":
    "X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization, x-gemini-api-key, x-api-key, x-device-token",
  "Access-Control-Max-Age": "86400",
};

/**
 * Returns a standard preflight 204 response with permissive CORS headers.
 */
export function handleOptions(): NextResponse {
  return new NextResponse(null, {
    status: 204,
    headers: CORS_HEADERS,
  });
}

/**
 * Attaches standard CORS headers to any existing response or init.
 */
export function withCors(response: Response): Response {
  Object.entries(CORS_HEADERS).forEach(([key, value]) => {
    if (!response.headers.has(key)) {
      response.headers.set(key, value);
    }
  });
  return response;
}

/**
 * Helper to produce a JSON response with pre-attached CORS headers.
 */
export function jsonResponse<T>(data: T, init?: ResponseInit | number): NextResponse<T> {
  const initObj: ResponseInit = typeof init === "number" ? { status: init } : init || {};
  const headers = new Headers(initObj.headers);
  Object.entries(CORS_HEADERS).forEach(([key, value]) => {
    if (!headers.has(key)) {
      headers.set(key, value);
    }
  });
  headers.set("Content-Type", "application/json; charset=utf-8");

  return NextResponse.json(data, {
    ...initObj,
    headers,
  });
}
