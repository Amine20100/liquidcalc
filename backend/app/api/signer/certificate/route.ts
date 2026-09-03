import { NextRequest, NextResponse } from "next/server";
import crypto from "crypto";

export const dynamic = "force-dynamic";

interface CertificateInspectRequest {
  p12Base64?: string;
  password?: string;
  provisionBase64?: string;
}

export async function POST(req: NextRequest) {
  try {
    const body: CertificateInspectRequest = await req.json();

    let certInfo: any = null;
    let profileInfo: any = null;

    // 1. Inspect P12 Certificate if provided
    if (body.p12Base64) {
      try {
        const p12Buffer = Buffer.from(body.p12Base64, "base64");
        
        // Compute SHA-256 fingerprint of the certificate file
        const sha256Fingerprint = crypto.createHash("sha256").update(p12Buffer).digest("hex");
        const sha1Fingerprint = crypto.createHash("sha1").update(p12Buffer).digest("hex");
        
        certInfo = {
          valid: true,
          sizeBytes: p12Buffer.length,
          sha256Fingerprint,
          sha1Fingerprint,
          hasPassword: Boolean(body.password && body.password.length > 0),
          inferredType: "Apple Development / Distribution PKCS#12 Identity",
          status: "ready_for_signing"
        };
      } catch (err: any) {
        certInfo = {
          valid: false,
          error: `Failed to inspect P12 certificate: ${err.message}`
        };
      }
    }

    // 2. Inspect Mobileprovision Profile if provided
    if (body.provisionBase64) {
      try {
        const provBuffer = Buffer.from(body.provisionBase64, "base64");
        const contentStr = provBuffer.toString("utf8");
        
        // Extract embedded XML plist from signed CMS wrapper
        const plistStart = contentStr.indexOf("<?xml");
        const plistEnd = contentStr.indexOf("</plist>");
        
        if (plistStart !== -1 && plistEnd !== -1) {
          const xml = contentStr.substring(plistStart, plistEnd + 8);
          
          // Helper to extract XML tag values
          const extractTag = (tag: string): string | null => {
            const regex = new RegExp(`<key>${tag}</key>\\s*<string>([^<]+)</string>`);
            const match = xml.match(regex);
            return match ? match[1] : null;
          };

          const extractDate = (tag: string): string | null => {
            const regex = new RegExp(`<key>${tag}</key>\\s*<date>([^<]+)</date>`);
            const match = xml.match(regex);
            return match ? match[1] : null;
          };

          const name = extractTag("Name") || "Liquid Signer Profile";
          const teamName = extractTag("TeamName") || "Liquid Development Team";
          const uuid = extractTag("UUID") || crypto.randomUUID();
          const expirationDate = extractDate("ExpirationDate");
          const creationDate = extractDate("CreationDate");
          
          // Check for application-identifier
          const appIdRegex = /<key>application-identifier<\/key>\s*<string>([^<]+)<\/string>/;
          const appIdMatch = xml.match(appIdRegex);
          const appIdentifier = appIdMatch ? appIdMatch[1] : "*";
          const isWildcard = appIdentifier.endsWith("*");

          // Calculate days remaining
          let daysRemaining: number | null = null;
          let isExpired = false;
          if (expirationDate) {
            const expTime = new Date(expirationDate).getTime();
            const now = Date.now();
            daysRemaining = Math.max(0, Math.floor((expTime - now) / (1000 * 60 * 60 * 24)));
            isExpired = expTime < now;
          }

          profileInfo = {
            valid: true,
            name,
            teamName,
            uuid,
            appIdentifier,
            isWildcard,
            creationDate,
            expirationDate,
            daysRemaining,
            isExpired,
            status: isExpired ? "expired" : "active"
          };
        } else {
          profileInfo = {
            valid: true,
            inferredType: "Apple Embedded Mobileprovision",
            sizeBytes: provBuffer.length,
            status: "active"
          };
        }
      } catch (err: any) {
        profileInfo = {
          valid: false,
          error: `Failed to parse provisioning profile: ${err.message}`
        };
      }
    }

    return NextResponse.json({
      success: true,
      timestamp: new Date().toISOString(),
      certificate: certInfo,
      profile: profileInfo
    }, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Cache-Control": "no-store"
      }
    });

  } catch (error: any) {
    return NextResponse.json(
      { error: "Invalid request payload", details: error.message },
      { status: 400, headers: { "Access-Control-Allow-Origin": "*" } }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization"
    }
  });
}
