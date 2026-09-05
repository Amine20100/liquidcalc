import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { DEFAULT_IPA_URL, DEFAULT_ICON_URL } from "@/lib/ota";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function GET(req: NextRequest) {
  const host = req.headers.get("host") || "liquidcalc.vercel.app";
  const protocol = req.headers.get("x-forwarded-proto") || "https";
  const baseUrl = `${protocol}://${host}`;

  const payload = {
    id: 230001,
    tag_name: "v2.3.0",
    name: "LiquidCalc v2.3.0 - Serverless Suite & Gemini 2.5 Flash",
    body: "LiquidCalc v2.3.0 production release featuring Gemini 2.5 Flash SSE streaming proxy, dynamic Apple itms-services OTA manifest generator, and real-time calculation history sync.",
    html_url: "https://github.com/Amine20100/liquidcalc/releases/tag/v2.3.0",
    published_at: "2026-09-02T05:00:00Z",
    prerelease: false,
    draft: false,
    assets: [
      {
        id: 133701,
        name: "LiquidCalc.ipa",
        size: 5782076,
        download_count: 2480,
        browser_download_url: "https://github.com/Amine20100/liquidcalc/releases/download/v2.3.0/LiquidCalc.ipa",
        content_type: "application/octet-stream",
      },
    ],
    source: {
      name: "LiquidCalc Official Source",
      identifier: "com.liquidcalc.source",
      sourceURL: `${baseUrl}/api/updates/latest`,
      apps: [
        {
          name: "LiquidCalc",
          bundleIdentifier: "com.liquidcalc.app",
          developerName: "LiquidCalc Team",
          version: "2.3.0",
          versionDate: "2026-09-01",
          versionDescription:
            "Production Next.js serverless backend suite with Gemini 2.5 Flash streaming proxy, Apple itms-services OTA sideloading, and calculation history sync.",
          downloadURL: DEFAULT_IPA_URL,
          localizedDescription:
            "LiquidCalc is a pure native Swift 6 / iOS 18+ calculator with liquid glass aesthetics, Apple Vision OCR, CoreHaptics, and comprehensive Advanced Mathematics.",
          iconURL: DEFAULT_ICON_URL,
          tintColor: "#00F0FF",
          size: 5242880,
          minOSVersion: "17.0",
          screenshots: [DEFAULT_ICON_URL],
        },
      ],
      news: [
        {
          title: "LiquidCalc v2.3.0 Released!",
          identifier: "liquidcalc-v2.3.0",
          caption: "Added Gemini 2.5 Flash SSE streaming, OTA wireless signing, and real-time history sync.",
          date: "2026-09-01",
          appID: "com.liquidcalc.app",
          notify: true,
        },
      ],
    },
  };

  return jsonResponse(payload, {
    status: 200,
    headers: {
      "Cache-Control": "public, max-age=300, s-maxage=300",
    },
  });
}
