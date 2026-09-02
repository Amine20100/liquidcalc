import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { buildItmsServicesUrl, DEFAULT_BUNDLE_ID, DEFAULT_IPA_URL } from "@/lib/ota";

export const dynamic = "force-dynamic";

const LATEST_VERSION = "2.3.0";
const LATEST_BUILD = "23";
const RELEASE_DATE = "2026-09-01";
const RELEASE_TITLE = "LiquidCalc v2.3.0 - Serverless AI & OTA Distribution Hub";

const CHANGELOG = [
  "Integrated Gemini 2.5 Flash SSE streaming proxy with multimodal OCR and math tutoring",
  "Dynamic Apple itms-services OTA manifest hosting for 1-tap wireless sideloading",
  "Real-time calculation history synchronization with UUID deduplication and mode filtering",
  "Full symbolic calculus, matrix decompositions, complex numbers, and multi-currency receipt splitting",
  "Glassmorphic cyberpunk dark dashboard with live telemetry and interactive API tester",
];

function parseSemVer(versionStr: string): [number, number, number] {
  const clean = versionStr.replace(/^v/i, "").trim();
  const parts = clean.split(".").map((p) => parseInt(p, 10) || 0);
  return [parts[0] || 0, parts[1] || 0, parts[2] || 0];
}

function isNewer(latest: string, current: string): boolean {
  const [lMaj, lMin, lPat] = parseSemVer(latest);
  const [cMaj, cMin, cPat] = parseSemVer(current);

  if (lMaj !== cMaj) return lMaj > cMaj;
  if (lMin !== cMin) return lMin > cMin;
  return lPat > cPat;
}

export async function OPTIONS() {
  return handleOptions();
}

export async function GET(req: NextRequest) {
  const searchParams = req.nextUrl.searchParams;
  const currentVersion = searchParams.get("currentVersion") || searchParams.get("version") || "1.0.0";
  const bundleId = searchParams.get("bundleId") || DEFAULT_BUNDLE_ID;

  const host = req.headers.get("host") || "liquidcalc.vercel.app";
  const protocol = req.headers.get("x-forwarded-proto") || "https";
  const baseUrl = `${protocol}://${host}`;

  const otaManifestURL = `${baseUrl}/api/ota/manifest?bundleId=${encodeURIComponent(
    bundleId
  )}&version=${LATEST_VERSION}`;
  const otaInstallURL = buildItmsServicesUrl(otaManifestURL);

  const updateAvailable = isNewer(LATEST_VERSION, currentVersion);

  const payload = {
    updateAvailable,
    currentVersion,
    latestVersion: LATEST_VERSION,
    buildNumber: LATEST_BUILD,
    releaseDate: RELEASE_DATE,
    title: RELEASE_TITLE,
    downloadURL: DEFAULT_IPA_URL,
    otaManifestURL,
    otaInstallURL,
    changelog: CHANGELOG,
    minOSVersion: "17.0",
  };

  return jsonResponse(payload, {
    status: 200,
    headers: {
      "Cache-Control": "public, max-age=300, s-maxage=300",
    },
  });
}
