import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { DEFAULT_PLANS, TIER_LIMITS, seedPlansAndPromoCodes } from "@/lib/subscription";
import { prisma } from "@/lib/prisma";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function GET(req: NextRequest) {
  await seedPlansAndPromoCodes();

  let dbPlans: any[] = [];
  try {
    dbPlans = await prisma.plan.findMany({
      where: { active: true },
      orderBy: { priceUsd: "asc" },
    });
  } catch {
    // Fallback if DB not ready
  }

  const plans = (dbPlans.length > 0 ? dbPlans : DEFAULT_PLANS).map((p: any) => ({
    id: p.id,
    name: p.name,
    tier: p.tier,
    priceUsd: p.priceUsd,
    billingPeriod: p.billingPeriod,
    description: p.description,
    features: typeof p.features === "string" ? JSON.parse(p.features) : p.features,
  }));

  return jsonResponse({
    success: true,
    plans,
    tierEntitlements: TIER_LIMITS,
    comparison: [
      {
        feature: "Cloud Synchronization",
        free: "Basic quota (50 items)",
        pro: "Unlimited across all devices",
        ultra: "Unlimited with real-time sync",
      },
      {
        feature: "Over-The-Air (OTA) Signing",
        free: "Not available",
        pro: "Standard Enterprise signing",
        ultra: "Priority & custom provisioning profiles",
      },
      {
        feature: "Gemini 2.5 Pro Multimodal AI",
        free: "Standard math solver",
        pro: "Standard math solver + OCR",
        ultra: "Priority AI solver & fast streaming",
      },
      {
        feature: "Export Formats",
        free: "TXT, CSV",
        pro: "TXT, CSV, JSON, LaTeX, PDF",
        ultra: "TXT, CSV, JSON, LaTeX, PDF, Word DOCX, Typst",
      },
      {
        feature: "Device Limit",
        free: "1 device",
        pro: "Up to 5 devices",
        ultra: "Unlimited devices",
      },
      {
        feature: "Custom Themes & Styles",
        free: "Standard",
        pro: "Dark, OLED, Solarized, Nord",
        ultra: "All themes + Custom CSS/Palette",
      },
    ],
  });
}
