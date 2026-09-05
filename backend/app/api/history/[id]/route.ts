import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { historyStore } from "@/lib/storage";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const id = params.id;
  const item = historyStore.get(id) || (await historyStore.getAsync(id));

  if (!item) {
    return jsonResponse({ error: "Calculation not found" }, 404);
  }

  return jsonResponse({ success: true, item }, 200);
}

export async function PUT(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const id = params.id;
  let body: any = {};
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON request body" }, 400);
  }

  const existing = historyStore.get(id) || (await historyStore.getAsync(id));
  if (!existing) {
    // If not found, upsert as new calculation
    const now = new Date().toISOString();
    historyStore.sync([
      {
        id,
        timestamp: body.timestamp || now,
        expression: String(body.expression || ""),
        result: String(body.result || ""),
        mode: String(body.mode || "standard"),
        notes: body.notes ? String(body.notes) : undefined,
        deviceId: body.deviceId || "unknown",
        userId: body.userId,
        updatedAt: now,
      },
    ]);
    const created = historyStore.get(id);
    return jsonResponse({ success: true, message: "Calculation created", item: created }, 200);
  }

  const updated = historyStore.update(id, {
    expression: typeof body.expression === "string" ? body.expression.trim() : undefined,
    result: typeof body.result === "string" ? body.result.trim() : undefined,
    mode: typeof body.mode === "string" ? body.mode.trim().toLowerCase() : undefined,
    notes: typeof body.notes === "string" ? body.notes : undefined,
    deviceId: typeof body.deviceId === "string" ? body.deviceId : undefined,
    userId: typeof body.userId === "string" ? body.userId : undefined,
  });

  return jsonResponse({ success: true, message: "Calculation updated successfully", item: updated }, 200);
}

export async function DELETE(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const id = params.id;
  const deleted = historyStore.delete(id);

  if (!deleted) {
    return jsonResponse({ error: "Calculation not found" }, 404);
  }

  return jsonResponse(
    {
      success: true,
      message: "Calculation deleted successfully",
      id,
    },
    200
  );
}
