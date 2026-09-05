/**
 * In-Memory & SQLite Calculation History Synchronization Engine
 * Supports UUID deduplication, mode filtering, device filtering, search,
 * bidirectional syncing with Last-Write-Wins (LWW) conflict resolution, and pagination.
 */

import { prisma } from "./prisma";

export interface HistoryItem {
  id: string;
  timestamp: string;
  expression: string;
  result: string;
  mode: string;
  notes?: string;
  deviceId?: string;
  userId?: string;
  updatedAt?: string;
  deleted?: boolean;
}

export interface SyncResult {
  success: boolean;
  syncedCount: number;
  totalRecords: number;
  lastSyncTimestamp: string;
  serverItems?: HistoryItem[];
}

export interface ListResult {
  success: boolean;
  count: number;
  total: number;
  offset: number;
  limit: number;
  items: HistoryItem[];
}

// Initial seed history items showcasing various calculation modes
export const SEED_HISTORY: HistoryItem[] = [
  {
    id: "f47ac10b-58cc-4372-a567-0e02b2c3d479",
    timestamp: "2026-09-02T05:30:00.000Z",
    expression: "d/dx(x^3 * sin(x) + e^(2x))",
    result: "3x^2*sin(x) + x^3*cos(x) + 2*e^(2x)",
    mode: "calculus",
    notes: "Symbolic product rule derivative with exponential component",
    deviceId: "iPhone16,2-Seed",
  },
  {
    id: "7c9e6679-7425-40de-944b-e07fc1f90ae7",
    timestamp: "2026-09-02T05:15:00.000Z",
    expression: "det([[3, 7], [1, -4]])",
    result: "-19",
    mode: "matrix",
    notes: "2x2 determinant calculation for eigenvalue problem",
    deviceId: "iPad14,3-Seed",
  },
  {
    id: "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
    timestamp: "2026-09-02T04:45:00.000Z",
    expression: "245.50 * 1.20 - 15%",
    result: "250.41",
    mode: "standard",
    notes: "Dinner bill split with 20% tip and 15% discount coupon",
    deviceId: "iPhone16,2-Seed",
  },
  {
    id: "3e2a1b9c-8d7e-4f5a-b6c7-d8e9f0a1b2c3",
    timestamp: "2026-09-02T04:10:00.000Z",
    expression: "0x7FFA & 0x00FF",
    result: "0xFA (250)",
    mode: "programmer",
    notes: "Bitwise AND operation on memory register offset",
    deviceId: "MacBookPro18,1-Seed",
  },
  {
    id: "5a4b3c2d-1e0f-9a8b-7c6d-5e4f3a2b1c0d",
    timestamp: "2026-09-02T03:30:00.000Z",
    expression: "1250 USD -> EUR @ 0.92",
    result: "1150.00 EUR",
    mode: "converter",
    notes: "FX foreign currency conversion for travel expenses",
    deviceId: "iPhone16,2-Seed",
  },
  {
    id: "8f7e6d5c-4b3a-2f1e-0d9c-8b7a6f5e4d3c",
    timestamp: "2026-09-02T02:00:00.000Z",
    expression: "Receipt OCR: Starbucks Coffee + Bakery Item",
    result: "Total: $14.85 (Subtotal: $13.50, Tax: $1.35)",
    mode: "receipt",
    notes: "Smart Vision OCR scanned receipt in San Francisco",
    deviceId: "iPhone16,2-Seed",
  },
];

class HistoryStore {
  private itemsMap: Map<string, HistoryItem> = new Map();
  private lastUpdated: string = new Date().toISOString();

  constructor() {
    for (const item of SEED_HISTORY) {
      this.itemsMap.set(item.id, item);
    }
    this.persistSeedHistory().then(() => this.hydrateFromDatabase()).catch(() => {});
  }

  private async persistSeedHistory() {
    try {
      for (const item of SEED_HISTORY) {
        await prisma.calculation.upsert({
          where: { id: item.id },
          update: {},
          create: {
            id: item.id,
            expression: item.expression,
            result: item.result,
            mode: item.mode,
            notes: item.notes,
            deviceId: item.deviceId,
            clientTime: new Date(item.timestamp),
            createdAt: new Date(item.timestamp),
            updatedAt: new Date(item.timestamp),
          },
        });
      }
    } catch {
      // Ignore if DB not ready
    }
  }

  public async hydrateFromDatabase() {
    try {
      const records = await prisma.calculation.findMany();
      for (const rec of records) {
        this.itemsMap.set(rec.id, {
          id: rec.id,
          timestamp: rec.clientTime.toISOString(),
          expression: rec.expression,
          result: rec.result,
          mode: rec.mode,
          notes: rec.notes || undefined,
          deviceId: rec.deviceId || undefined,
          userId: rec.userId || undefined,
          updatedAt: rec.updatedAt.toISOString(),
          deleted: rec.deleted,
        });
      }
    } catch {
      // Ignore if DB not ready
    }
  }

  public sync(
    items: HistoryItem[],
    deviceId?: string,
    since?: string,
    userId?: string
  ): SyncResult {
    let synced = 0;
    const now = new Date().toISOString();

    for (const raw of items) {
      if (!raw || typeof raw !== "object") continue;
      const id = raw.id || `calc_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
      const timestamp = raw.timestamp || now;
      const expression = String(raw.expression || "").trim();
      const result = String(raw.result || "").trim();
      const mode = String(raw.mode || "standard").toLowerCase().trim();
      const notes = raw.notes ? String(raw.notes) : undefined;
      const itemDeviceId = raw.deviceId || deviceId || "unknown";
      const itemUserId = raw.userId || userId;
      const isDeleted = Boolean(raw.deleted);

      if (!expression && !result && !isDeleted) continue;

      // Conflict Resolution: Last-Write-Wins (LWW)
      const existing = this.itemsMap.get(id);
      if (existing) {
        const existingTime = new Date(existing.timestamp).getTime();
        const incomingTime = new Date(timestamp).getTime();
        if (!isNaN(existingTime) && !isNaN(incomingTime) && existingTime > incomingTime) {
          continue;
        }
      }

      const item: HistoryItem = {
        id,
        timestamp,
        expression,
        result,
        mode,
        notes,
        deviceId: itemDeviceId,
        userId: itemUserId || existing?.userId,
        updatedAt: now,
        deleted: isDeleted,
      };

      this.itemsMap.set(id, item);
      synced += 1;

      // Asynchronous background persistence to SQLite
      try {
        prisma.calculation
          .upsert({
            where: { id },
            update: {
              expression,
              result,
              mode,
              notes,
              deviceId: itemDeviceId,
              userId: item.userId || undefined,
              updatedAt: new Date(now),
              deleted: isDeleted,
            },
            create: {
              id,
              expression,
              result,
              mode,
              notes,
              deviceId: itemDeviceId,
              userId: item.userId || undefined,
              clientTime: new Date(timestamp),
              createdAt: new Date(timestamp),
              updatedAt: new Date(now),
              deleted: isDeleted,
            },
          })
          .catch(() => {});
      } catch {
        // Ignore DB error
      }
    }

    this.lastUpdated = now;

    // Collect server records modified since `since` (bidirectional sync)
    let serverItems: HistoryItem[] | undefined = undefined;
    if (since) {
      const sinceTime = new Date(since).getTime();
      if (!isNaN(sinceTime)) {
        serverItems = Array.from(this.itemsMap.values()).filter((item) => {
          const t = new Date(item.updatedAt || item.timestamp).getTime();
          return !isNaN(t) && t > sinceTime;
        });
      }
    }

    const activeCount = Array.from(this.itemsMap.values()).filter((i) => !i.deleted).length;

    return {
      success: true,
      syncedCount: synced,
      totalRecords: activeCount,
      lastSyncTimestamp: this.lastUpdated,
      serverItems,
    };
  }

  public list(params?: {
    mode?: string;
    deviceId?: string;
    userId?: string;
    limit?: number;
    offset?: number;
    search?: string;
    since?: string;
    includeDeleted?: boolean;
  }): ListResult {
    let all = Array.from(this.itemsMap.values());

    // Filter out deleted unless specified
    if (!params?.includeDeleted) {
      all = all.filter((i) => !i.deleted);
    }

    // Filter by deviceId
    if (params?.deviceId && params.deviceId.trim().length > 0) {
      const devId = params.deviceId.trim();
      all = all.filter((item) => item.deviceId === devId);
    }

    // Filter by userId
    if (params?.userId && params.userId.trim().length > 0) {
      const uId = params.userId.trim();
      all = all.filter((item) => item.userId === uId);
    }

    // Filter by mode
    if (params?.mode && params.mode.trim().length > 0) {
      const modeFilter = params.mode.trim().toLowerCase();
      if (modeFilter !== "all") {
        all = all.filter((item) => item.mode.toLowerCase() === modeFilter);
      }
    }

    // Filter by search query
    if (params?.search && params.search.trim().length > 0) {
      const q = params.search.trim().toLowerCase();
      all = all.filter(
        (item) =>
          item.id.toLowerCase().includes(q) ||
          item.expression.toLowerCase().includes(q) ||
          item.result.toLowerCase().includes(q) ||
          (item.deviceId && item.deviceId.toLowerCase().includes(q)) ||
          (item.notes && item.notes.toLowerCase().includes(q))
      );
    }

    // Filter by since
    if (params?.since && params.since.trim().length > 0) {
      const sinceTime = new Date(params.since.trim()).getTime();
      if (!isNaN(sinceTime)) {
        all = all.filter((item) => {
          const t = new Date(item.updatedAt || item.timestamp).getTime();
          return !isNaN(t) && t > sinceTime;
        });
      }
    }

    // Sort newest first defensively
    all.sort((a, b) => {
      const tA = new Date(a.timestamp).getTime();
      const tB = new Date(b.timestamp).getTime();
      return (isNaN(tB) ? 0 : tB) - (isNaN(tA) ? 0 : tA);
    });

    const total = all.length;
    const offset = Math.max(0, Number(params?.offset) || 0);
    const limit = Math.min(200, Math.max(1, Number(params?.limit) || 50));
    const paginated = offset >= total ? [] : all.slice(offset, offset + limit);

    return {
      success: true,
      count: paginated.length,
      total,
      offset,
      limit,
      items: paginated,
    };
  }

  public get(id: string): HistoryItem | null {
    const item = this.itemsMap.get(id);
    return item && !item.deleted ? item : null;
  }

  public async getAsync(id: string): Promise<HistoryItem | null> {
    const cached = this.get(id);
    if (cached) return cached;
    try {
      const rec = await prisma.calculation.findUnique({ where: { id } });
      if (rec && !rec.deleted) {
        const item: HistoryItem = {
          id: rec.id,
          timestamp: rec.clientTime.toISOString(),
          expression: rec.expression,
          result: rec.result,
          mode: rec.mode,
          notes: rec.notes || undefined,
          deviceId: rec.deviceId || undefined,
          userId: rec.userId || undefined,
          updatedAt: rec.updatedAt.toISOString(),
          deleted: rec.deleted,
        };
        this.itemsMap.set(id, item);
        return item;
      }
    } catch {
      // Ignore
    }
    return null;
  }

  public update(id: string, updates: Partial<HistoryItem>): HistoryItem | null {
    const item = this.itemsMap.get(id);
    if (!item || item.deleted) return null;

    const now = new Date().toISOString();
    if (updates.expression !== undefined) item.expression = updates.expression;
    if (updates.result !== undefined) item.result = updates.result;
    if (updates.mode !== undefined) item.mode = updates.mode;
    if (updates.notes !== undefined) item.notes = updates.notes;
    if (updates.deviceId !== undefined) item.deviceId = updates.deviceId;
    if (updates.userId !== undefined) item.userId = updates.userId;
    item.updatedAt = now;

    this.itemsMap.set(id, item);
    this.lastUpdated = now;

    try {
      prisma.calculation
        .upsert({
          where: { id },
          update: {
            expression: item.expression,
            result: item.result,
            mode: item.mode,
            notes: item.notes,
            deviceId: item.deviceId,
            userId: item.userId,
            updatedAt: new Date(now),
          },
          create: {
            id,
            expression: item.expression,
            result: item.result,
            mode: item.mode,
            notes: item.notes,
            deviceId: item.deviceId,
            userId: item.userId,
            clientTime: new Date(item.timestamp),
            createdAt: new Date(item.timestamp),
            updatedAt: new Date(now),
            deleted: Boolean(item.deleted),
          },
        })
        .catch(() => {});
    } catch {
      // Ignore
    }

    return item;
  }

  public delete(id: string): boolean {
    const item = this.itemsMap.get(id);
    if (!item) return false;
    item.deleted = true;
    item.updatedAt = new Date().toISOString();
    this.itemsMap.set(id, item);
    this.lastUpdated = item.updatedAt;

    try {
      prisma.calculation
        .updateMany({
          where: { id },
          data: { deleted: true, updatedAt: new Date() },
        })
        .catch(() => {});
    } catch {
      // Ignore
    }

    return true;
  }

  public clear(): void {
    this.itemsMap.clear();
    this.lastUpdated = new Date().toISOString();
  }

  public getStats() {
    const active = Array.from(this.itemsMap.values()).filter((i) => !i.deleted);
    const modes: Record<string, number> = {};
    for (const item of active) {
      modes[item.mode] = (modes[item.mode] || 0) + 1;
    }
    return {
      totalCount: active.length,
      modesCount: modes,
      lastUpdated: this.lastUpdated,
    };
  }
}

// Global singleton instance for Next.js hot-reloading preservation
const globalForStorage = globalThis as unknown as {
  __liquidCalcHistoryStore?: HistoryStore;
};

export const historyStore =
  globalForStorage.__liquidCalcHistoryStore ?? new HistoryStore();

if (process.env.NODE_ENV !== "production") {
  globalForStorage.__liquidCalcHistoryStore = historyStore;
}
