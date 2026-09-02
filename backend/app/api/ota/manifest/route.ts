import { NextRequest } from "next/server";
import { handleOptions, CORS_HEADERS } from "@/lib/cors";
import { generateIosManifestXml } from "@/lib/ota";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function GET(req: NextRequest) {
  const searchParams = req.nextUrl.searchParams;

  const bundleId = searchParams.get("bundleId") || searchParams.get("bundleIdentifier") || undefined;
  const name = searchParams.get("name") || searchParams.get("title") || searchParams.get("appName") || undefined;
  const version = searchParams.get("version") || searchParams.get("bundleVersion") || undefined;
  const ipaUrl = searchParams.get("ipaUrl") || searchParams.get("url") || undefined;
  const iconUrl = searchParams.get("iconUrl") || undefined;

  const xmlContent = generateIosManifestXml({
    bundleId,
    name,
    version,
    ipaUrl,
    iconUrl,
  });

  const headers = new Headers(CORS_HEADERS);
  headers.set("Content-Type", "text/xml; charset=utf-8");
  headers.set("Cache-Control", "public, max-age=3600, s-maxage=3600");

  return new Response(xmlContent, {
    status: 200,
    headers,
  });
}
