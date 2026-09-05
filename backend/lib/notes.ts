/**
 * LiquidCalc Math Notes & Markdown Notebooks Synchronization Engine
 * Bidirectional sync with Last-Write-Wins (LWW) conflict resolution and tombstone support.
 * Modeled for native iOS WorkspaceDocument & WorkspaceAttachment integration.
 */

import { prisma } from "./prisma";

export interface WorkspaceAttachment {
  id: string;
  kind: "scan" | "aiAnswer" | "calculation";
  summary: string;
  createdAt: string;
}

export interface NoteItem {
  id: string;
  title: string;
  markdown: string;
  tags: string[];
  attachments: WorkspaceAttachment[];
  createdAt: string;
  updatedAt: string;
  deviceId?: string;
  userId?: string;
  deleted?: boolean;
}

export interface NoteSyncResult {
  success: boolean;
  syncedCount: number;
  totalRecords: number;
  lastSyncTimestamp: string;
  serverNotes?: NoteItem[];
}

export interface NoteListResult {
  success: boolean;
  count: number;
  total: number;
  offset: number;
  limit: number;
  items: NoteItem[];
}

const SEED_NOTES: NoteItem[] = [
  {
    id: "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d",
    title: "Calculus: Integration by Parts",
    markdown:
      "## Integration by Parts Formula\n\n$$\\int u \\, dv = uv - \\int v \\, du$$\n\n### Example:\nEvaluate $\\int x \\cos(x) \\, dx$\n\n- Let $u = x \\implies du = dx$\n- Let $dv = \\cos(x) dx \\implies v = \\sin(x)$\n\n$$\\int x \\cos(x) \\, dx = x\\sin(x) - \\int \\sin(x) \\, dx = x\\sin(x) + \\cos(x) + C$$",
    tags: ["calculus", "study", "formulas"],
    attachments: [
      {
        id: "att-001",
        kind: "aiAnswer",
        summary: "Step-by-step calculus derivation for integration by parts",
        createdAt: "2026-09-02T04:00:00.000Z",
      },
    ],
    createdAt: "2026-09-02T04:00:00.000Z",
    updatedAt: "2026-09-02T04:00:00.000Z",
    deviceId: "iPad14,3-Seed",
  },
  {
    id: "b2c3d4e5-f6a7-5b6c-9d0e-1f2a3b4c5d6e",
    title: "Linear Algebra: Eigenvalues & Determinants",
    markdown:
      "## Characteristic Polynomial\n\nFor a matrix $A$, the eigenvalues $\\lambda$ satisfy:\n\n$$\\det(A - \\lambda I) = 0$$\n\nFor $2 \\times 2$ matrix $\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}$:\n- Trace: $\\operatorname{tr}(A) = a + d = \\lambda_1 + \\lambda_2$\n- Determinant: $\\det(A) = ad - bc = \\lambda_1 \\lambda_2$",
    tags: ["matrix", "algebra", "exam-prep"],
    attachments: [
      {
        id: "att-002",
        kind: "calculation",
        summary: "det([[3, 7], [1, -4]]) = -19",
        createdAt: "2026-09-02T05:15:00.000Z",
      },
    ],
    createdAt: "2026-09-02T05:15:00.000Z",
    updatedAt: "2026-09-02T05:15:00.000Z",
    deviceId: "iPhone16,2-Seed",
  },
];

class NotesStore {
  private notesMap: Map<string, NoteItem> = new Map();
  private lastUpdated: string = new Date().toISOString();

  constructor() {
    for (const note of SEED_NOTES) {
      this.notesMap.set(note.id, note);
    }
    // Asynchronously sync seed notes to SQLite then hydrate
    this.persistSeedNotes().then(() => this.hydrateFromDatabase()).catch(() => {});
  }

  private async persistSeedNotes() {
    try {
      for (const note of SEED_NOTES) {
        await prisma.note.upsert({
          where: { id: note.id },
          update: {},
          create: {
            id: note.id,
            title: note.title,
            markdown: note.markdown,
            tags: JSON.stringify(note.tags),
            attachments: JSON.stringify(note.attachments),
            deviceId: note.deviceId,
            createdAt: new Date(note.createdAt),
            updatedAt: new Date(note.updatedAt),
          },
        });
      }
    } catch {
      // Ignore if DB not ready
    }
  }

  public async hydrateFromDatabase() {
    try {
      const records = await prisma.note.findMany();
      for (const rec of records) {
        let tags: string[] = [];
        let attachments: WorkspaceAttachment[] = [];
        try { tags = JSON.parse(rec.tags || "[]"); } catch {}
        try { attachments = JSON.parse(rec.attachments || "[]"); } catch {}

        this.notesMap.set(rec.id, {
          id: rec.id,
          title: rec.title,
          markdown: rec.markdown,
          tags,
          attachments,
          deviceId: rec.deviceId || undefined,
          userId: rec.userId || undefined,
          createdAt: rec.createdAt.toISOString(),
          updatedAt: rec.updatedAt.toISOString(),
          deleted: rec.deleted,
        });
      }
    } catch {
      // Ignore if DB not ready
    }
  }

  public async sync(
    notes: NoteItem[],
    deviceId?: string,
    since?: string,
    userId?: string
  ): Promise<NoteSyncResult> {
    let synced = 0;
    const now = new Date().toISOString();

    for (const raw of notes) {
      if (!raw || typeof raw !== "object") continue;
      const id = raw.id || `note_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
      const incomingUpdated = raw.updatedAt || now;
      const incomingCreated = raw.createdAt || incomingUpdated;
      const title = String(raw.title || "Untitled note").trim();
      const markdown = String(raw.markdown || "");
      const tags = Array.isArray(raw.tags)
        ? raw.tags.map((t) => String(t).trim().toLowerCase()).filter(Boolean)
        : [];
      const attachments = Array.isArray(raw.attachments) ? raw.attachments : [];
      const itemDeviceId = raw.deviceId || deviceId || "unknown";
      const itemUserId = raw.userId || userId;
      const isDeleted = Boolean(raw.deleted);

      // Conflict Resolution: Last-Write-Wins (LWW)
      const existing = this.notesMap.get(id);
      if (existing) {
        const existingTime = new Date(existing.updatedAt).getTime();
        const incomingTime = new Date(incomingUpdated).getTime();

        // If existing record is newer than incoming, client's update is stale
        if (!isNaN(existingTime) && !isNaN(incomingTime) && existingTime > incomingTime) {
          continue;
        }
      }

      const note: NoteItem = {
        id,
        title,
        markdown,
        tags,
        attachments,
        createdAt: existing?.createdAt || incomingCreated,
        updatedAt: incomingUpdated,
        deviceId: itemDeviceId,
        userId: itemUserId || existing?.userId,
        deleted: isDeleted,
      };

      this.notesMap.set(id, note);
      synced += 1;

      // Persist to Prisma
      try {
        await prisma.note.upsert({
          where: { id },
          update: {
            title,
            markdown,
            tags: JSON.stringify(tags),
            attachments: JSON.stringify(attachments),
            deviceId: itemDeviceId,
            userId: note.userId || undefined,
            updatedAt: new Date(incomingUpdated),
            deleted: isDeleted,
          },
          create: {
            id,
            title,
            markdown,
            tags: JSON.stringify(tags),
            attachments: JSON.stringify(attachments),
            deviceId: itemDeviceId,
            userId: note.userId || undefined,
            createdAt: new Date(incomingCreated),
            updatedAt: new Date(incomingUpdated),
            deleted: isDeleted,
          },
        });
      } catch {
        // Fallback to in-memory map
      }
    }

    this.lastUpdated = now;

    // Collect server notes modified since `since` timestamp (for bidirectional sync)
    let serverNotes: NoteItem[] | undefined = undefined;
    if (since) {
      const sinceTime = new Date(since).getTime();
      if (!isNaN(sinceTime)) {
        serverNotes = Array.from(this.notesMap.values()).filter((n) => {
          const t = new Date(n.updatedAt).getTime();
          return !isNaN(t) && t > sinceTime;
        });
      }
    }

    const activeRecords = Array.from(this.notesMap.values()).filter((n) => !n.deleted);

    return {
      success: true,
      syncedCount: synced,
      totalRecords: activeRecords.length,
      lastSyncTimestamp: this.lastUpdated,
      serverNotes,
    };
  }

  public list(params?: {
    tag?: string;
    deviceId?: string;
    userId?: string;
    search?: string;
    limit?: number;
    offset?: number;
    includeDeleted?: boolean;
  }): NoteListResult {
    let all = Array.from(this.notesMap.values());

    // Filter out deleted unless explicitly requested
    if (!params?.includeDeleted) {
      all = all.filter((n) => !n.deleted);
    }

    // Filter by deviceId
    if (params?.deviceId && params.deviceId.trim().length > 0) {
      const dev = params.deviceId.trim();
      all = all.filter((n) => n.deviceId === dev);
    }

    // Filter by userId
    if (params?.userId && params.userId.trim().length > 0) {
      const uId = params.userId.trim();
      all = all.filter((n) => n.userId === uId);
    }

    // Filter by tag
    if (params?.tag && params.tag.trim().length > 0) {
      const t = params.tag.trim().toLowerCase();
      all = all.filter((n) => n.tags.includes(t));
    }

    // Filter by search query
    if (params?.search && params.search.trim().length > 0) {
      const q = params.search.trim().toLowerCase();
      all = all.filter(
        (n) =>
          n.title.toLowerCase().includes(q) ||
          n.markdown.toLowerCase().includes(q) ||
          n.tags.some((tag) => tag.toLowerCase().includes(q))
      );
    }

    // Sort newest updated first
    all.sort((a, b) => {
      const tA = new Date(a.updatedAt).getTime();
      const tB = new Date(b.updatedAt).getTime();
      return (isNaN(tB) ? 0 : tB) - (isNaN(tA) ? 0 : tA);
    });

    const total = all.length;
    const offset = Math.max(0, Number(params?.offset) || 0);
    const limit = Math.min(100, Math.max(1, Number(params?.limit) || 20));
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

  public get(id: string): NoteItem | null {
    const note = this.notesMap.get(id);
    return note && !note.deleted ? note : null;
  }

  public async getAsync(id: string): Promise<NoteItem | null> {
    const cached = this.get(id);
    if (cached) return cached;
    try {
      const rec = await prisma.note.findUnique({ where: { id } });
      if (rec && !rec.deleted) {
        let tags: string[] = [];
        let attachments: WorkspaceAttachment[] = [];
        try { tags = JSON.parse(rec.tags || "[]"); } catch {}
        try { attachments = JSON.parse(rec.attachments || "[]"); } catch {}

        const item: NoteItem = {
          id: rec.id,
          title: rec.title,
          markdown: rec.markdown,
          tags,
          attachments,
          deviceId: rec.deviceId || undefined,
          userId: rec.userId || undefined,
          createdAt: rec.createdAt.toISOString(),
          updatedAt: rec.updatedAt.toISOString(),
          deleted: rec.deleted,
        };
        this.notesMap.set(id, item);
        return item;
      }
    } catch {}
    return null;
  }

  public delete(id: string): boolean {
    const note = this.notesMap.get(id);
    if (!note) return false;
    note.deleted = true;
    note.updatedAt = new Date().toISOString();
    this.notesMap.set(id, note);
    this.lastUpdated = note.updatedAt;

    try {
      prisma.note
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

  public getStats() {
    const active = Array.from(this.notesMap.values()).filter((n) => !n.deleted);
    const allTags = new Set<string>();
    for (const note of active) {
      note.tags.forEach((t) => allTags.add(t));
    }

    return {
      totalCount: active.length,
      tagsCount: allTags.size,
      lastUpdated: this.lastUpdated,
    };
  }
}

const globalForNotes = globalThis as unknown as {
  __liquidCalcNotesStore?: NotesStore;
};

export const notesStore =
  globalForNotes.__liquidCalcNotesStore ?? new NotesStore();

if (process.env.NODE_ENV !== "production") {
  globalForNotes.__liquidCalcNotesStore = notesStore;
}
