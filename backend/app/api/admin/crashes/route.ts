import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import { verifyAdminRequest, listAdminCrashes } from "@/lib/admin";
import { telemetryStore } from "@/lib/telemetry";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

/**
 * GET /api/admin/crashes
 * Real-time crash log stream with stack traces, app versions, and device models.
 */
export async function GET(req: NextRequest) {
  const auth = await verifyAdminRequest(req);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.error }, auth.status);
  }

  const { searchParams } = req.nextUrl;
  const search = searchParams.get("search") || undefined;
  const appVersion = searchParams.get("appVersion") || undefined;
  const limit = searchParams.get("limit") ? parseInt(searchParams.get("limit")!, 10) : 30;
  const offset = searchParams.get("offset") ? parseInt(searchParams.get("offset")!, 10) : 0;

  try {
    const data = await listAdminCrashes({
      search,
      appVersion,
      limit,
      offset,
    });
    return jsonResponse(data, 200);
  } catch (err: any) {
    return jsonResponse({ error: "Failed to list crashes", details: err.message }, 500);
  }
}

/**
 * POST /api/admin/crashes
 * Diagnostic simulator endpoint to record a test crash event.
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

  const errorTitle = body.error || body.name || "EXC_BAD_ACCESS Simulated Admin Crash";
  const stack =
    body.stack ||
    body.trace ||
    `Thread 0 Crashed:\n0  libsystem_kernel.dylib  0x00000001804210a4 mach_msg2_trap + 8\n1  LiquidCalc             0x00000001004523a0 MatrixComputeEngine.solve() + 142\n2  LiquidCalc             0x00000001002341b8 SwiftUIRenderer.draw() + 68`;

  try {
    const recorded = await telemetryStore.record({
      type: "crash",
      name: errorTitle,
      payload: {
        error: errorTitle,
        stack,
        diagnostic: true,
        triggeredBy: auth.adminUser?.email || "admin",
      },
      deviceId: body.deviceId || "iPhone16,2-AdminTester",
      appVersion: body.appVersion || "2.3.0",
      osVersion: body.osVersion || "iOS 18.2",
    });

    return jsonResponse(
      {
        success: true,
        message: "Diagnostic crash event recorded",
        crash: recorded,
      },
      201
    );
  } catch (err: any) {
    return jsonResponse({ error: "Failed to record crash", details: err.message }, 500);
  }
}
