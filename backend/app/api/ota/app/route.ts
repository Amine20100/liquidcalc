import { NextRequest, NextResponse } from "next/server";
import { handleOptions, CORS_HEADERS } from "@/lib/cors";
import { DEFAULT_IPA_URL } from "@/lib/ota";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function GET(req: NextRequest) {
  const searchParams = req.nextUrl.searchParams;
  const targetUrl = searchParams.get("url") || DEFAULT_IPA_URL;

  const headers = new Headers(CORS_HEADERS);
  headers.set("Location", targetUrl);

  return new NextResponse(null, {
    status: 302,
    headers,
  });
}
