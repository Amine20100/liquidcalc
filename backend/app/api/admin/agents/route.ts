import { NextRequest } from "next/server";
import { jsonResponse, handleOptions } from "@/lib/cors";
import {
  verifyAdminRequest,
  listSystemAgents,
  executeSystemAgentAction,
  toggleSystemAgentStatus,
} from "@/lib/admin";

export const dynamic = "force-dynamic";

export async function OPTIONS() {
  return handleOptions();
}

/**
 * GET /api/admin/agents
 * Returns list of registered backend system agents, tools, and telemetry metrics.
 */
export async function GET(req: NextRequest) {
  const auth = await verifyAdminRequest(req);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.error }, auth.status);
  }

  try {
    const data = await listSystemAgents();
    return jsonResponse(data, 200);
  } catch (err: any) {
    return jsonResponse(
      { error: "Failed to list system agents", details: err.message },
      500
    );
  }
}

/**
 * POST /api/admin/agents
 * Dispatches an interactive query or maintenance task to a specific system agent.
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
    return jsonResponse({ error: "Invalid JSON request body" }, 400);
  }

  const { agentId, action, prompt, options } = body;
  if (!agentId) {
    return jsonResponse(
      { error: "Missing required parameter 'agentId'" },
      400
    );
  }

  try {
    const result = await executeSystemAgentAction({
      agentId,
      action,
      prompt,
      options,
    });
    return jsonResponse(result, 200);
  } catch (err: any) {
    return jsonResponse(
      { error: err.message || "Failed to execute agent action" },
      400
    );
  }
}

/**
 * PATCH /api/admin/agents
 * Toggles status (active / paused) for a specific system agent.
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
    return jsonResponse({ error: "Invalid JSON request body" }, 400);
  }

  const { agentId, status } = body;
  if (!agentId || !status) {
    return jsonResponse(
      { error: "Parameters 'agentId' and 'status' ('active' | 'paused') are required" },
      400
    );
  }

  if (status !== "active" && status !== "paused") {
    return jsonResponse(
      { error: "Status must be either 'active' or 'paused'" },
      400
    );
  }

  try {
    const result = await toggleSystemAgentStatus(agentId, status);
    return jsonResponse(result, 200);
  } catch (err: any) {
    return jsonResponse(
      { error: err.message || "Failed to update agent status" },
      400
    );
  }
}
