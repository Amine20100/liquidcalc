import { PrismaClient } from "@prisma/client";
import fs from "fs";
import path from "path";

function initDatabaseUrl(): string {
  // If explicitly configured with an external connection URL (e.g. turso, postgres)
  if (process.env.DATABASE_URL && !process.env.DATABASE_URL.startsWith("file:")) {
    return process.env.DATABASE_URL;
  }

  // Detect serverless environment (Vercel, AWS Lambda)
  const isServerless = Boolean(
    process.env.VERCEL ||
    process.env.AWS_LAMBDA_FUNCTION_NAME ||
    process.env.LAMBDA_TASK_ROOT
  );

  if (isServerless) {
    const tmpDbPath = path.join("/tmp", "dev.db");

    // Copy seeded dev.db to writable /tmp on container cold start if not present
    if (!fs.existsSync(tmpDbPath)) {
      const candidates = [
        path.join("/var/task", "prisma", "dev.db"),
        path.join(process.cwd(), "prisma", "dev.db"),
        path.join(process.cwd(), "dev.db"),
      ];
      let copied = false;
      for (const candidate of candidates) {
        if (fs.existsSync(candidate)) {
          try {
            fs.copyFileSync(candidate, tmpDbPath);
            try { fs.chmodSync(tmpDbPath, 0o666); } catch {}
            copied = true;
            console.log(`[Prisma] Seeded writable database at ${tmpDbPath} from ${candidate}`);
            break;
          } catch (e) {
            console.warn(`[Prisma] Failed to copy seed db from ${candidate}:`, e);
          }
        }
      }
      if (!copied) {
        console.warn(`[Prisma] Warning: source dev.db not found in candidate paths`);
      }
    }

    const resolvedUrl = `file:${tmpDbPath}`;
    process.env.DATABASE_URL = resolvedUrl;
    return resolvedUrl;
  }

  // Local development / testing
  if (!process.env.DATABASE_URL) {
    process.env.DATABASE_URL = "file:./dev.db";
  }
  return process.env.DATABASE_URL;
}

initDatabaseUrl();

const globalForPrisma = globalThis as unknown as {
  prisma?: PrismaClient;
};

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === "development" ? ["warn", "error"] : ["error"],
  });

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;
}

export default prisma;

