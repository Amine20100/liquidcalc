import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export async function GET() {
  const uptime = process.uptime();
  
  return NextResponse.json({
    service: "Liquid Signer Cloud Server",
    status: "operational",
    version: "2.5.0",
    engine: "Pure-TypeScript / Node Cryptographic SuperBlob & Mach-O Pipeline",
    supportedArchitectures: ["arm64", "arm64e", "universal2"],
    signingAlgorithms: [
      "sha256WithRSAEncryption",
      "sha1WithRSAEncryption",
      "ecdsa-with-SHA256"
    ],
    capabilities: {
      dylibInjection: true,
      loadCommandPatching: "LC_LOAD_DYLIB",
      entitlementsInjection: true,
      appCloning: true,
      extensionStripping: true,
      appleOtaManifest: true,
      trollStoreDeepLinks: true
    },
    system: {
      platform: process.platform,
      nodeVersion: process.version,
      uptimeSeconds: Math.floor(uptime),
      timestamp: new Date().toISOString()
    }
  }, {
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Cache-Control": "no-store"
    }
  });
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization"
    }
  });
}
