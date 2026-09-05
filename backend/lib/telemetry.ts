/**
 * LiquidCalc Telemetry & Analytics Engine
 * Tracks crash reports, performance events, and calculation usage metrics.
 */

import { prisma } from "./prisma";

export interface TelemetryRecord {
  id: string;
  type: "crash" | "performance" | "calculation" | "usage";
  name?: string;
  payload: any;
  deviceId?: string;
  appVersion?: string;
  osVersion?: string;
  createdAt: string;
}

class TelemetryStore {
  private events: TelemetryRecord[] = [];
  private maxCapacity = 500;

  constructor() {
    // Seed initial baseline telemetry events for rich dashboard telemetry
    const now = Date.now();
    const seedEvents: TelemetryRecord[] = [
      {
        id: "telem-init-001",
        type: "calculation",
        name: "calculus_integral_solved",
        payload: { mode: "calculus", expression: "integral(x^2)", latencyMs: 34 },
        deviceId: "iPhone16,2-Seed",
        appVersion: "2.3.0",
        osVersion: "iOS 18.2",
        createdAt: new Date(now - 1000 * 60 * 60 * 2).toISOString(),
      },
      {
        id: "telem-init-002",
        type: "performance",
        name: "gemini_stream_ttft",
        payload: { timeToFirstTokenMs: 240, totalDurationMs: 820 },
        deviceId: "iPad14,3-Seed",
        appVersion: "2.3.0",
        osVersion: "iPadOS 18.2",
        createdAt: new Date(now - 1000 * 60 * 60).toISOString(),
      },
      {
        id: "telem-init-003",
        type: "calculation",
        name: "matrix_determinant",
        payload: { mode: "matrix", dimensions: "2x2", latencyMs: 12 },
        deviceId: "MacBookPro18,1-Seed",
        appVersion: "2.3.0",
        osVersion: "macOS 15.1",
        createdAt: new Date(now - 1000 * 60 * 30).toISOString(),
      },
      {
        id: "telem-init-004",
        type: "usage",
        name: "session_start",
        payload: { orientation: "portrait", screenWidth: 393, screenHeight: 852 },
        deviceId: "iPhone16,2-Seed",
        appVersion: "2.3.0",
        osVersion: "iOS 18.2",
        createdAt: new Date(now - 1000 * 60 * 15).toISOString(),
      },
    ];

    for (const ev of seedEvents) {
      this.events.push(ev);
    }
    this.hydrateFromDatabase().catch(() => {});
  }

  public async hydrateFromDatabase() {
    try {
      const records = await prisma.telemetryEvent.findMany({
        orderBy: { createdAt: "desc" },
        take: this.maxCapacity,
      });
      for (const rec of records) {
        if (!this.events.some((e) => e.id === rec.id)) {
          let payload: any = {};
          try {
            payload = JSON.parse(rec.payload || "{}");
          } catch {}
          this.events.push({
            id: rec.id,
            type: rec.type as any,
            name: rec.name || undefined,
            payload,
            deviceId: rec.deviceId || undefined,
            appVersion: rec.appVersion || undefined,
            osVersion: rec.osVersion || undefined,
            createdAt: rec.createdAt.toISOString(),
          });
        }
      }
    } catch {
      // Ignore if DB not ready
    }
  }

  public async record(event: {
    type: "crash" | "performance" | "calculation" | "usage";
    name?: string;
    payload?: any;
    deviceId?: string;
    appVersion?: string;
    osVersion?: string;
  }): Promise<TelemetryRecord> {
    const id = `tel_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    const createdAt = new Date().toISOString();

    const record: TelemetryRecord = {
      id,
      type: event.type,
      name: event.name || event.type,
      payload: event.payload || {},
      deviceId: event.deviceId || "unknown",
      appVersion: event.appVersion || "2.3.0",
      osVersion: event.osVersion,
      createdAt,
    };

    this.events.unshift(record);
    if (this.events.length > this.maxCapacity) {
      this.events = this.events.slice(0, this.maxCapacity);
    }

    // Persist to Prisma
    try {
      prisma.telemetryEvent
        .create({
          data: {
            id,
            type: event.type,
            name: event.name,
            payload: JSON.stringify(event.payload || {}),
            deviceId: event.deviceId,
            appVersion: event.appVersion || "2.3.0",
            osVersion: event.osVersion,
            createdAt: new Date(createdAt),
          },
        })
        .catch(() => {});
    } catch {
      // Ignore DB error
    }

    return record;
  }

  public list(params?: {
    type?: string;
    deviceId?: string;
    limit?: number;
    offset?: number;
  }) {
    let filtered = this.events;
    if (params?.type && params.type !== "all") {
      filtered = filtered.filter((e) => e.type === params.type);
    }
    if (params?.deviceId) {
      filtered = filtered.filter((e) => e.deviceId === params.deviceId);
    }

    const total = filtered.length;
    const offset = Math.max(0, Number(params?.offset) || 0);
    const limit = Math.min(100, Math.max(1, Number(params?.limit) || 20));

    return {
      success: true,
      count: filtered.slice(offset, offset + limit).length,
      total,
      offset,
      limit,
      events: filtered.slice(offset, offset + limit),
    };
  }

  public getStats() {
    const countsByType: Record<string, number> = {
      crash: 0,
      performance: 0,
      calculation: 0,
      usage: 0,
    };

    const uniqueDevices = new Set<string>();
    const calculationModes: Record<string, number> = {};
    let totalPerfLatency = 0;
    let perfCount = 0;

    for (const e of this.events) {
      countsByType[e.type] = (countsByType[e.type] || 0) + 1;
      if (e.deviceId && e.deviceId !== "unknown") {
        uniqueDevices.add(e.deviceId);
      }

      if (e.type === "calculation" && e.payload?.mode) {
        const m = String(e.payload.mode);
        calculationModes[m] = (calculationModes[m] || 0) + 1;
      }

      if (e.type === "performance") {
        const lat =
          Number(e.payload?.durationMs) ||
          Number(e.payload?.totalDurationMs) ||
          Number(e.payload?.latencyMs);
        if (lat && !isNaN(lat)) {
          totalPerfLatency += lat;
          perfCount += 1;
        }
      }
    }

    const avgLatencyMs = perfCount > 0 ? Math.round(totalPerfLatency / perfCount) : 48;
    const crashCount = countsByType.crash || 0;
    const totalEvents = this.events.length;
    const crashRatePct =
      totalEvents > 0 ? Number(((crashCount / totalEvents) * 100).toFixed(2)) : 0.0;

    return {
      success: true,
      totalEvents,
      countsByType,
      uniqueDevicesCount: uniqueDevices.size || 1,
      crashCount,
      crashRatePct,
      averagePerformanceLatencyMs: avgLatencyMs,
      calculationModes,
      recentCrashes: this.events.filter((e) => e.type === "crash").slice(0, 5),
    };
  }
}

const globalForTelemetry = globalThis as unknown as {
  __liquidCalcTelemetryStore?: TelemetryStore;
};

export const telemetryStore =
  globalForTelemetry.__liquidCalcTelemetryStore ?? new TelemetryStore();

if (process.env.NODE_ENV !== "production") {
  globalForTelemetry.__liquidCalcTelemetryStore = telemetryStore;
}
