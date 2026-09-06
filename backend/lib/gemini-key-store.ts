import { prisma } from "@/lib/prisma";

let inMemoryApiKey: string = "";

/**
 * Sets the active Gemini API key in runtime memory.
 */
export function setRuntimeGeminiApiKey(key: string): void {
  inMemoryApiKey = key.trim();
}

/**
 * Returns the current runtime in-memory Gemini API key.
 */
export function getRuntimeGeminiApiKey(): string {
  return inMemoryApiKey;
}

/**
 * Resolves the active Gemini API key, falling back to SQLite database or environment.
 */
export async function getPersistedGeminiApiKey(): Promise<string> {
  if (inMemoryApiKey) {
    return inMemoryApiKey;
  }

  // Check process.env
  if (process.env.GEMINI_API_KEY && process.env.GEMINI_API_KEY.trim().length > 0) {
    inMemoryApiKey = process.env.GEMINI_API_KEY.trim();
    return inMemoryApiKey;
  }

  // Check SQLite ApiKey table
  try {
    const record = await prisma.apiKey.findFirst({
      where: { name: "gemini_api_key", active: true },
      orderBy: { createdAt: "desc" },
    });
    if (record && record.key) {
      inMemoryApiKey = record.key;
      return record.key;
    }
  } catch (err) {
    // Database might still be initializing or unavailable
  }

  return "";
}

/**
 * Persists a new Gemini API key to SQLite and updates the in-memory cache.
 */
export async function savePersistedGeminiApiKey(key: string): Promise<void> {
  const trimmed = key.trim();
  inMemoryApiKey = trimmed;

  try {
    // Deactivate prior gemini_api_key entries
    await prisma.apiKey.updateMany({
      where: { name: "gemini_api_key" },
      data: { active: false },
    });

    if (trimmed) {
      await prisma.apiKey.create({
        data: {
          name: "gemini_api_key",
          key: trimmed,
          active: true,
        },
      });
    }
  } catch (err) {
    console.warn("[GeminiKeyStore] Failed to persist key to SQLite database:", err);
  }
}

/**
 * Masks an API key for safe display in the Admin Panel UI (e.g. AIzaSy...94c0).
 */
export function maskApiKey(key: string): string {
  if (!key) return "Not Configured";
  if (key.length <= 8) return "••••••••";
  const prefix = key.slice(0, 6);
  const suffix = key.slice(-4);
  return `${prefix}${"•".repeat(Math.max(key.length - 10, 4))}${suffix}`;
}
