import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import {
  verifyAdminRequest,
  listAdminPromos,
  createAdminPromo,
  toggleAdminPromo,
  deleteAdminPromo,
} from "@/lib/admin";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

/**
 * GET /api/admin/promos
 * List all promotional codes with redemption counts and status.
 */
export async function GET(req: NextRequest) {
  const auth = await verifyAdminRequest(req);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.error }, auth.status);
  }

  try {
    const data = await listAdminPromos();
    return jsonResponse(data, 200);
  } catch (err: any) {
    return jsonResponse({ error: "Failed to list promo codes", details: err.message }, 500);
  }
}

/**
 * POST /api/admin/promos
 * Create a new promotional discount or upgrade code.
 */
export async function POST(req: NextRequest) {
  const auth = await verifyAdminRequest(req);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.error }, auth.status);
  }

  let body: any = {};
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const { code, tier, durationDays, maxUses, expiresAt } = body;
  if (!code) {
    return jsonResponse({ error: "Missing required parameter 'code'" }, 400);
  }

  try {
    const result = await createAdminPromo({
      code,
      tier: tier || "PRO",
      durationDays: durationDays || 30,
      maxUses: maxUses || 100,
      expiresAt,
    });
    return jsonResponse(result, 201);
  } catch (err: any) {
    return jsonResponse({ error: err.message || "Failed to create promo code" }, 400);
  }
}

/**
 * PATCH /api/admin/promos
 * Toggle active state or update promo code properties.
 */
export async function PATCH(req: NextRequest) {
  const auth = await verifyAdminRequest(req);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.error }, auth.status);
  }

  let body: any = {};
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const { id, code, active } = body;
  if (!id && !code) {
    return jsonResponse({ error: "Must specify promo 'id' or 'code'" }, 400);
  }

  try {
    const result = await toggleAdminPromo({
      id,
      code,
      active: Boolean(active),
    });
    return jsonResponse(result, 200);
  } catch (err: any) {
    return jsonResponse({ error: err.message || "Failed to update promo code" }, 400);
  }
}

/**
 * DELETE /api/admin/promos
 * Revoke and remove a promo code.
 */
export async function DELETE(req: NextRequest) {
  const auth = await verifyAdminRequest(req);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.error }, auth.status);
  }

  const { searchParams } = req.nextUrl;
  let id = searchParams.get("id");
  let code = searchParams.get("code");

  if (!id && !code) {
    try {
      const body = await req.json();
      id = body.id;
      code = body.code;
    } catch {}
  }

  if (!id && !code) {
    return jsonResponse({ error: "Must specify promo 'id' or 'code' to delete" }, 400);
  }

  try {
    const result = await deleteAdminPromo({ id: id || undefined, code: code || undefined });
    return jsonResponse(result, 200);
  } catch (err: any) {
    return jsonResponse({ error: err.message || "Failed to delete promo code" }, 400);
  }
}
