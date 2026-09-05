"use client";

import React, { useState, useEffect, useCallback } from "react";
import Link from "next/link";
import {
  Activity,
  Cpu,
  Sparkles,
  Download,
  Database,
  Terminal,
  Server,
  Zap,
  CheckCircle2,
  RefreshCw,
  Copy,
  Code,
  Layers,
  Send,
  Play,
  FileCode2,
  Shield,
  ShieldCheck,
  Smartphone,
  Lock,
  User,
  Key,
  BookOpen,
  Bug,
  BarChart3,
  Radio,
  Plus,
} from "lucide-react";

interface HealthData {
  status: string;
  healthy: boolean;
  timestamp: string;
  uptime: number;
  version: string;
  environment: string;
  region: string;
  services: {
    gemini_gateway: { status: string; model: string };
    ota_signer: { status: string; bundleId: string };
    updates_dist: { status: string; latestVersion: string; buildNumber: string };
    history_sync: { status: string; recordsCount: number };
    notes_sync?: { status: string; notesCount: number; tagsCount: number };
    auth_service?: { status: string; features: string[]; activeSessions?: number };
    telemetry_analytics?: { status: string; totalEvents: number; crashCount: number; crashRatePct: number };
    database_sqlite?: { status: string; provider: string; orm: string };
  };
}

interface HistoryItem {
  id: string;
  timestamp: string;
  expression: string;
  result: string;
  mode: string;
  notes?: string;
  deviceId?: string;
}

interface NoteItem {
  id: string;
  title: string;
  markdown: string;
  tags: string[];
  attachments: any[];
  updatedAt: string;
  deviceId?: string;
}

interface TelemetryStats {
  totalEvents: number;
  countsByType: Record<string, number>;
  uniqueDevicesCount: number;
  crashCount: number;
  crashRatePct: number;
  averagePerformanceLatencyMs: number;
  calculationModes: Record<string, number>;
  activeSessions?: number;
}

export default function DashboardPage() {
  const [health, setHealth] = useState<HealthData | null>(null);
  const [loadingHealth, setLoadingHealth] = useState(true);
  const [activeTab, setActiveTab] = useState<
    "ai" | "auth" | "history" | "notes" | "ota" | "telemetry"
  >("ai");

  // Gemini Stream Sandbox State
  const [aiPrompt, setAiPrompt] = useState(
    "Evaluate integral of (3x^2 + 2x) * e^x dx with step-by-step calculus derivation"
  );
  const [aiStreaming, setAiStreaming] = useState(false);
  const [aiOutput, setAiOutput] = useState("");
  const [streamChunksCount, setStreamChunksCount] = useState(0);

  // Auth Sandbox State
  const [authEmail, setAuthEmail] = useState("student@liquidcalc.local");
  const [authPassword, setAuthPassword] = useState("supersecret123");
  const [authName, setAuthName] = useState("Alexandre Grothendieck");
  const [authToken, setAuthToken] = useState("");
  const [deviceToken, setDeviceToken] = useState("");
  const [authOutput, setAuthOutput] = useState("");
  const [authLoading, setAuthLoading] = useState(false);

  // OTA Tester State
  const [otaBundleId, setOtaBundleId] = useState("com.liquidcalc.app");
  const [otaAppName, setOtaAppName] = useState("LiquidCalc");
  const [otaVersion, setOtaVersion] = useState("2.3.0");
  const [otaXmlPreview, setOtaXmlPreview] = useState("");
  const [loadingOta, setLoadingOta] = useState(false);

  // History State
  const [historyItems, setHistoryItems] = useState<HistoryItem[]>([]);
  const [historyMode, setHistoryMode] = useState("all");
  const [loadingHistory, setLoadingHistory] = useState(false);
  const [newExpr, setNewExpr] = useState("det([[4, 2], [1, 3]])");
  const [newResult, setNewResult] = useState("10");
  const [newMode, setNewMode] = useState("matrix");

  // Notes State
  const [notesItems, setNotesItems] = useState<NoteItem[]>([]);
  const [loadingNotes, setLoadingNotes] = useState(false);
  const [newNoteTitle, setNewNoteTitle] = useState("Matrix Decompositions");
  const [newNoteMarkdown, setNewNoteMarkdown] = useState(
    "## Singular Value Decomposition (SVD)\n\n$$A = U \\Sigma V^T$$\n\n- $U$: Orthogonal matrix of left singular vectors\n- $\\Sigma$: Diagonal singular values"
  );
  const [newNoteTag, setNewNoteTag] = useState("linear-algebra");

  // Telemetry Sandbox State
  const [telemetryStats, setTelemetryStats] = useState<TelemetryStats | null>(null);
  const [telemetryLogs, setTelemetryLogs] = useState<any[]>([]);
  const [crashMessage, setCrashMessage] = useState("EXC_BAD_ACCESS in MatrixInversion.metal");
  const [sendingTelemetry, setSendingTelemetry] = useState(false);
  const [activeSessionsList, setActiveSessionsList] = useState<any[]>([]);

  // API Explorer Inspector State
  const [selectedEndpoint, setSelectedEndpoint] = useState<string | null>(null);
  const [endpointResponse, setEndpointResponse] = useState<string>("");
  const [endpointTesting, setEndpointTesting] = useState(false);
  const [copiedText, setCopiedText] = useState<string | null>(null);

  // Fetch Health
  const fetchHealth = useCallback(async () => {
    try {
      setLoadingHealth(true);
      const res = await fetch("/api/health");
      if (res.ok) {
        const data = await res.json();
        setHealth(data);
      }
      fetch("/api/auth/sessions")
        .then((r) => r.json())
        .then((d) => setActiveSessionsList(d.sessions || []))
        .catch(() => {});
    } catch {
      // Fallback
    } finally {
      setLoadingHealth(false);
    }
  }, []);

  // Fetch History
  const fetchHistory = useCallback(async (mode = "all") => {
    try {
      setLoadingHistory(true);
      const url = mode === "all" ? "/api/history/list" : `/api/history/list?mode=${mode}`;
      const res = await fetch(url);
      if (res.ok) {
        const data = await res.json();
        setHistoryItems(data.items || []);
      }
    } catch {
      // Fallback
    } finally {
      setLoadingHistory(false);
    }
  }, []);

  // Fetch Notes
  const fetchNotes = useCallback(async () => {
    try {
      setLoadingNotes(true);
      const res = await fetch("/api/notes");
      if (res.ok) {
        const data = await res.json();
        setNotesItems(data.items || []);
      }
    } catch {
      // Fallback
    } finally {
      setLoadingNotes(false);
    }
  }, []);

  // Fetch Telemetry Stats
  const fetchTelemetry = useCallback(async () => {
    try {
      const resStats = await fetch("/api/telemetry/stats");
      if (resStats.ok) {
        const data = await resStats.json();
        setTelemetryStats(data.telemetry);
      }
      const resEvents = await fetch("/api/telemetry/events?limit=10");
      if (resEvents.ok) {
        const data = await resEvents.json();
        setTelemetryLogs(data.events || []);
      }
    } catch {
      // Fallback
    }
  }, []);

  // Fetch OTA Manifest Preview
  const fetchOtaPreview = useCallback(async () => {
    try {
      setLoadingOta(true);
      const url = `/api/ota/manifest?bundleId=${encodeURIComponent(
        otaBundleId
      )}&name=${encodeURIComponent(otaAppName)}&version=${encodeURIComponent(
        otaVersion
      )}`;
      const res = await fetch(url);
      if (res.ok) {
        const text = await res.text();
        setOtaXmlPreview(text);
      }
    } catch {
      // Fallback
    } finally {
      setLoadingOta(false);
    }
  }, [otaBundleId, otaAppName, otaVersion]);

  useEffect(() => {
    fetchHealth();
    fetchHistory();
    fetchNotes();
    fetchTelemetry();
    fetchOtaPreview();
  }, [fetchHealth, fetchHistory, fetchNotes, fetchTelemetry, fetchOtaPreview]);

  // Handle SSE Stream Test
  const handleStartStream = async () => {
    if (!aiPrompt.trim() || aiStreaming) return;
    setAiStreaming(true);
    setAiOutput("");
    setStreamChunksCount(0);

    try {
      const headers: Record<string, string> = { "Content-Type": "application/json" };
      if (authToken) headers["Authorization"] = `Bearer ${authToken}`;

      const res = await fetch("/api/ai/stream", {
        method: "POST",
        headers,
        body: JSON.stringify({
          prompt: aiPrompt,
          temperature: 0.2,
        }),
      });

      if (!res.ok || !res.body) {
        setAiOutput("Stream connection failed.");
        setAiStreaming(false);
        return;
      }

      const reader = res.body.getReader();
      const decoder = new TextDecoder("utf-8");
      let buffer = "";

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split("\n");
        buffer = lines.pop() || "";

        for (const line of lines) {
          const trimmed = line.trim();
          if (trimmed.startsWith("data: ")) {
            const jsonStr = trimmed.slice(6).trim();
            if (!jsonStr) continue;
            try {
              const parsed = JSON.parse(jsonStr);
              if (parsed.text) {
                setAiOutput((prev) => prev + parsed.text);
                setStreamChunksCount((c) => c + 1);
              }
            } catch {
              // Ignore
            }
          }
        }
      }
    } catch (err: unknown) {
      setAiOutput((prev) => prev + `\n[Stream Error: ${err instanceof Error ? err.message : String(err)}]`);
    } finally {
      setAiStreaming(false);
    }
  };

  // Auth Handlers
  const handleRegister = async () => {
    setAuthLoading(true);
    try {
      const res = await fetch("/api/auth/register", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: authEmail, password: authPassword, name: authName }),
      });
      const data = await res.json();
      setAuthOutput(JSON.stringify(data, null, 2));
      if (data.tokens?.accessToken) {
        setAuthToken(data.tokens.accessToken);
      }
    } catch (err: any) {
      setAuthOutput(`Error: ${err.message}`);
    } finally {
      setAuthLoading(false);
    }
  };

  const handleLogin = async () => {
    setAuthLoading(true);
    try {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: authEmail, password: authPassword }),
      });
      const data = await res.json();
      setAuthOutput(JSON.stringify(data, null, 2));
      if (data.tokens?.accessToken) {
        setAuthToken(data.tokens.accessToken);
      }
    } catch (err: any) {
      setAuthOutput(`Error: ${err.message}`);
    } finally {
      setAuthLoading(false);
    }
  };

  const handleIssueDeviceToken = async () => {
    setAuthLoading(true);
    try {
      const res = await fetch("/api/auth/device", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          deviceId: `iPhone16,2_${Math.random().toString(36).substring(2, 7)}`,
          platform: "ios",
          name: "Interactive Web Simulator Device",
        }),
      });
      const data = await res.json();
      setAuthOutput(JSON.stringify(data, null, 2));
      if (data.deviceToken) {
        setDeviceToken(data.deviceToken);
      }
    } catch (err: any) {
      setAuthOutput(`Error: ${err.message}`);
    } finally {
      setAuthLoading(false);
    }
  };

  // History Sync Handler
  const handleAddHistoryItem = async () => {
    if (!newExpr.trim() || !newResult.trim()) return;
    const newItem: HistoryItem = {
      id: `manual_${Date.now()}`,
      timestamp: new Date().toISOString(),
      expression: newExpr,
      result: newResult,
      mode: newMode,
      notes: "Interactive Sandbox Sync Entry",
      deviceId: "Web-Dashboard-Client",
    };

    try {
      const res = await fetch("/api/history/sync", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          deviceId: "Web-Dashboard",
          items: [newItem],
        }),
      });
      if (res.ok) {
        fetchHistory(historyMode);
        fetchHealth();
      }
    } catch {
      // Ignore
    }
  };

  // Notes Sync Handler
  const handleCreateNote = async () => {
    if (!newNoteTitle.trim()) return;
    try {
      const res = await fetch("/api/notes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          title: newNoteTitle,
          markdown: newNoteMarkdown,
          tags: [newNoteTag],
          attachments: [
            {
              id: `att_${Date.now()}`,
              kind: "aiAnswer",
              summary: "Generated from Web Sandbox",
              createdAt: new Date().toISOString(),
            },
          ],
          deviceId: "Web-Dashboard",
        }),
      });
      if (res.ok) {
        fetchNotes();
        fetchHealth();
        setNewNoteTitle("");
      }
    } catch {
      // Ignore
    }
  };

  // Telemetry Event Handler
  const handleSendCrash = async () => {
    setSendingTelemetry(true);
    try {
      await fetch("/api/telemetry/crash", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          error: crashMessage,
          stack: "Thread 0 Crashed:\n0 libmetal.dylib 0x0000000104123abc in MetalShaderContext\n1 LiquidCalc 0x00000001004523a0 in MatrixView.render()",
          deviceId: "Web-Simulator-Device",
          appVersion: "2.3.0",
          osVersion: "iOS 18.2",
        }),
      });
      fetchTelemetry();
      fetchHealth();
    } catch {
      // Ignore
    } finally {
      setSendingTelemetry(false);
    }
  };

  const handleSendPerf = async () => {
    setSendingTelemetry(true);
    try {
      await fetch("/api/telemetry/event", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          type: "performance",
          name: "gpu_matrix_compute",
          payload: { durationMs: Math.floor(Math.random() * 60) + 15 },
          deviceId: "Web-Simulator-Device",
          appVersion: "2.3.0",
        }),
      });
      fetchTelemetry();
      fetchHealth();
    } catch {
      // Ignore
    } finally {
      setSendingTelemetry(false);
    }
  };

  // Endpoint Inspector
  const testEndpoint = async (path: string, method: string, body?: object) => {
    setSelectedEndpoint(path);
    setEndpointTesting(true);
    setEndpointResponse("Executing request...");

    try {
      const headers: Record<string, string> = {};
      if (body) headers["Content-Type"] = "application/json";
      if (authToken) headers["Authorization"] = `Bearer ${authToken}`;
      if (deviceToken) headers["x-device-token"] = deviceToken;

      const options: RequestInit = { method, headers };
      if (body) options.body = JSON.stringify(body);

      const res = await fetch(path, options);
      const contentType = res.headers.get("content-type") || "";
      let output = "";

      if (contentType.includes("json")) {
        const json = await res.json();
        output = JSON.stringify(json, null, 2);
      } else {
        output = await res.text();
      }

      setEndpointResponse(
        `HTTP ${res.status} ${res.statusText}\nContent-Type: ${contentType}\n\n${output}`
      );
    } catch (err: unknown) {
      setEndpointResponse(`Request Failed: ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setEndpointTesting(false);
    }
  };

  const copyToClipboard = (text: string, id: string) => {
    navigator.clipboard.writeText(text);
    setCopiedText(id);
    setTimeout(() => setCopiedText(null), 2000);
  };

  const itmsUrl = `itms-services://?action=download-manifest&url=${encodeURIComponent(
    typeof window !== "undefined"
      ? `${window.location.origin}/api/ota/manifest?bundleId=${otaBundleId}&version=${otaVersion}`
      : `https://liquidcalc.vercel.app/api/ota/manifest?bundleId=${otaBundleId}&version=${otaVersion}`
  )}`;

  return (
    <div className="min-h-screen pb-20 cyber-grid bg-[#07090e] text-gray-200">
      {/* Top Cyberpunk Navbar */}
      <header className="sticky top-0 z-50 glass-panel border-b border-white/10 px-6 py-4 backdrop-blur-md bg-black/60">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-[#00F0FF] via-[#7928CA] to-[#FF007A] p-[2px] shadow-glowCyan">
              <div className="w-full h-full bg-[#07090e] rounded-[10px] flex items-center justify-center">
                <Sparkles className="w-5 h-5 text-[#00F0FF]" />
              </div>
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <span className="font-bold text-lg tracking-wider text-white">
                  LIQUID<span className="text-[#00F0FF]">CALC</span>
                </span>
                <span className="text-[10px] px-2 py-0.5 rounded-full bg-[#00F0FF]/10 text-[#00F0FF] border border-[#00F0FF]/30 font-mono">
                  v2.3.0 PROD
                </span>
                <span className="text-[10px] px-2 py-0.5 rounded-full bg-purple-500/10 text-purple-300 border border-purple-500/30 font-mono hidden sm:inline">
                  SQLITE + PRISMA
                </span>
              </div>
              <p className="text-xs text-gray-400 font-mono">
                Serverless Backend, JWT Auth, Sync Hub &amp; Gemini 2.5 Flash
              </p>
            </div>
          </div>

          <div className="flex items-center space-x-4">
            <Link
              href="/admin"
              className="flex items-center space-x-1.5 px-3 py-1.5 rounded-lg bg-gradient-to-r from-purple-500/20 to-[#00F0FF]/20 hover:from-purple-500/30 hover:to-[#00F0FF]/30 border border-[#00F0FF]/40 text-xs font-mono text-[#00F0FF] hover:text-white transition-all shadow-glowCyan"
              title="Open Backend Admin Panel"
            >
              <Shield className="w-3.5 h-3.5 text-[#00F0FF]" />
              <span className="font-bold tracking-wide">ADMIN PANEL</span>
            </Link>

            <div className="hidden md:flex items-center space-x-2 px-3 py-1.5 rounded-lg bg-black/40 border border-white/10 text-xs font-mono">
              <Server className="w-3.5 h-3.5 text-[#7928CA]" />
              <span className="text-gray-400">Database:</span>
              <span className="text-cyan-400">SQLite (dev.db)</span>
            </div>

            <div className="flex items-center space-x-2 px-3 py-1.5 rounded-lg bg-emerald-500/10 border border-emerald-500/30 text-xs font-mono">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
              </span>
              <span className="text-emerald-400 font-medium uppercase tracking-wider">
                {health?.status || "OPERATIONAL"}
              </span>
            </div>

            <button
              onClick={() => {
                fetchHealth();
                fetchHistory(historyMode);
                fetchNotes();
                fetchTelemetry();
              }}
              title="Refresh Telemetry"
              className="p-2 rounded-lg bg-white/5 hover:bg-white/10 border border-white/10 text-gray-300 hover:text-white transition-all"
            >
              <RefreshCw className={`w-4 h-4 ${loadingHealth ? "animate-spin" : ""}`} />
            </button>
          </div>
        </div>
      </header>

      {/* Main Content Area */}
      <main className="max-w-7xl mx-auto px-6 pt-8 space-y-8">
        {/* Hero Banner */}
        <section className="relative overflow-hidden rounded-2xl glass-panel p-8 border border-white/10 bg-black/40">
          <div className="absolute -right-20 -top-20 w-80 h-80 bg-[#00F0FF]/10 rounded-full blur-3xl pointer-events-none" />
          <div className="absolute -left-20 -bottom-20 w-80 h-80 bg-[#7928CA]/15 rounded-full blur-3xl pointer-events-none" />

          <div className="relative z-10 flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
            <div className="space-y-3">
              <div className="inline-flex items-center space-x-2 px-3 py-1 rounded-md bg-[#00F0FF]/10 border border-[#00F0FF]/30 text-[#00F0FF] text-xs font-mono">
                <Zap className="w-3.5 h-3.5" />
                <span>Next.js 14 App Router • SQLite Prisma Engine • Swift 6 OTA Gateway</span>
              </div>
              <h1 className="text-3xl sm:text-4xl font-extrabold tracking-tight text-white">
                LiquidCalc <span className="text-transparent bg-clip-text bg-gradient-to-r from-[#00F0FF] via-[#7928CA] to-[#00FFA3]">Cloud Control Center</span>
              </h1>
              <p className="text-sm text-gray-300 max-w-3xl leading-relaxed">
                Full-stack production serverless backend providing Gemini 2.5 Flash SSE streaming, JWT &amp; device token authentication, bidirectional calculation &amp; math notebook sync with LWW conflict resolution, Apple <code className="text-[#00F0FF] font-mono">itms-services</code> OTA sideloading, and telemetry analytics.
              </p>
            </div>

            <div className="flex flex-col sm:flex-row gap-3 w-full md:w-auto">
              <Link
                href="/admin"
                className="inline-flex items-center justify-center space-x-2 px-5 py-2.5 rounded-xl bg-gradient-to-r from-purple-600/80 to-[#7928CA]/80 hover:from-purple-600 hover:to-[#7928CA] text-white font-semibold text-xs uppercase tracking-wider border border-purple-400/40 transition-all shadow-lg"
              >
                <Shield className="w-4 h-4 text-[#00F0FF]" />
                <span>Open Admin Panel</span>
              </Link>
              <button
                onClick={() => testEndpoint("/api/health", "GET")}
                className="inline-flex items-center justify-center space-x-2 px-5 py-2.5 rounded-xl bg-[#00F0FF] text-black font-semibold text-xs uppercase tracking-wider hover:bg-[#00d0de] transition-all shadow-glowCyan"
              >
                <Activity className="w-4 h-4" />
                <span>Probe Health</span>
              </button>
              <a
                href={itmsUrl}
                className="inline-flex items-center justify-center space-x-2 px-5 py-2.5 rounded-xl bg-white/10 text-white font-medium text-xs uppercase tracking-wider hover:bg-white/15 border border-white/15 transition-all"
              >
                <Download className="w-4 h-4 text-[#00FFA3]" />
                <span>1-Tap iOS OTA</span>
              </a>
            </div>
          </div>
        </section>


        {/* 6 High-Density Service Cards */}
        <section className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
          {/* Card 1: Gemini 2.5 Flash */}
          <div className="glass-card rounded-xl p-5 border border-white/10 bg-black/40 flex flex-col justify-between space-y-4">
            <div className="flex items-center justify-between">
              <div className="w-10 h-10 rounded-lg bg-[#00F0FF]/10 border border-[#00F0FF]/30 flex items-center justify-center text-[#00F0FF]">
                <Cpu className="w-5 h-5" />
              </div>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                ACTIVE
              </span>
            </div>
            <div>
              <h3 className="font-semibold text-white text-base">Gemini 2.5 Flash Proxy</h3>
              <p className="text-xs text-gray-400 mt-1">
                Real-time SSE token streaming, multimodal math solver &amp; receipt OCR.
              </p>
            </div>
            <div className="pt-2 border-t border-white/10 flex items-center justify-between text-xs font-mono">
              <span className="text-gray-400">Endpoint</span>
              <span className="text-[#00F0FF]">/api/ai/stream</span>
            </div>
          </div>

          {/* Card 2: Auth & Mobile Tokens */}
          <div className="glass-card rounded-xl p-5 border border-white/10 bg-black/40 flex flex-col justify-between space-y-4">
            <div className="flex items-center justify-between">
              <div className="w-10 h-10 rounded-lg bg-yellow-500/10 border border-yellow-500/30 flex items-center justify-center text-yellow-400">
                <Lock className="w-5 h-5" />
              </div>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                ENABLED
              </span>
            </div>
            <div>
              <h3 className="font-semibold text-white text-base">JWT &amp; Device Tokens</h3>
              <p className="text-xs text-gray-400 mt-1">
                HS256 Bearer JWTs, iOS mobile client hardware tokens, API keys.
              </p>
            </div>
            <div className="pt-2 border-t border-white/10 flex items-center justify-between text-xs font-mono">
              <span className="text-gray-400">Endpoint</span>
              <span className="text-yellow-400">/api/auth/*</span>
            </div>
          </div>

          {/* Card 3: Real-Time Sync & Conflict Resolution */}
          <div className="glass-card rounded-xl p-5 border border-white/10 bg-black/40 flex flex-col justify-between space-y-4">
            <div className="flex items-center justify-between">
              <div className="w-10 h-10 rounded-lg bg-[#FF007A]/10 border border-[#FF007A]/30 flex items-center justify-center text-[#FF007A]">
                <Database className="w-5 h-5" />
              </div>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                SYNCED
              </span>
            </div>
            <div>
              <h3 className="font-semibold text-white text-base">Calculations &amp; Notes Sync</h3>
              <p className="text-xs text-gray-400 mt-1">
                Bidirectional LWW sync, soft delete tombstones, SQLite database.
              </p>
            </div>
            <div className="pt-2 border-t border-white/10 flex items-center justify-between text-xs font-mono">
              <span className="text-gray-400">Stored Records</span>
              <span className="text-[#FF007A]">{historyItems.length + notesItems.length} records</span>
            </div>
          </div>

          {/* Card 4: iOS OTA & Sideloading */}
          <div className="glass-card rounded-xl p-5 border border-white/10 bg-black/40 flex flex-col justify-between space-y-4">
            <div className="flex items-center justify-between">
              <div className="w-10 h-10 rounded-lg bg-[#7928CA]/10 border border-[#7928CA]/30 flex items-center justify-center text-[#7928CA]">
                <Smartphone className="w-5 h-5 text-purple-400" />
              </div>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                READY
              </span>
            </div>
            <div>
              <h3 className="font-semibold text-white text-base">Apple itms-services OTA</h3>
              <p className="text-xs text-gray-400 mt-1">
                Dynamic XML Plist manifest generator adhering to Apple DTD 1.0.
              </p>
            </div>
            <div className="pt-2 border-t border-white/10 flex items-center justify-between text-xs font-mono">
              <span className="text-gray-400">Bundle ID</span>
              <span className="text-purple-400">{otaBundleId}</span>
            </div>
          </div>

          {/* Card 5: Telemetry & Analytics */}
          <div className="glass-card rounded-xl p-5 border border-white/10 bg-black/40 flex flex-col justify-between space-y-4">
            <div className="flex items-center justify-between">
              <div className="w-10 h-10 rounded-lg bg-orange-500/10 border border-orange-500/30 flex items-center justify-center text-orange-400">
                <BarChart3 className="w-5 h-5" />
              </div>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                LIVE
              </span>
            </div>
            <div>
              <h3 className="font-semibold text-white text-base">Crash &amp; Performance Telemetry</h3>
              <p className="text-xs text-gray-400 mt-1">
                Crash reports, TTFT latency tracking, device metrics collection.
              </p>
            </div>
            <div className="pt-2 border-t border-white/10 flex items-center justify-between text-xs font-mono">
              <span className="text-gray-400">Avg Latency</span>
              <span className="text-orange-400">{telemetryStats?.averagePerformanceLatencyMs || 42}ms</span>
            </div>
          </div>

          {/* Card 6: Updates & AltStore Source */}
          <div className="glass-card rounded-xl p-5 border border-white/10 bg-black/40 flex flex-col justify-between space-y-4">
            <div className="flex items-center justify-between">
              <div className="w-10 h-10 rounded-lg bg-[#00FFA3]/10 border border-[#00FFA3]/30 flex items-center justify-center text-[#00FFA3]">
                <ShieldCheck className="w-5 h-5" />
              </div>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                v2.3.0
              </span>
            </div>
            <div>
              <h3 className="font-semibold text-white text-base">Release Distribution</h3>
              <p className="text-xs text-gray-400 mt-1">
                Direct IPA download redirects and AltStore repository compatibility.
              </p>
            </div>
            <div className="pt-2 border-t border-white/10 flex items-center justify-between text-xs font-mono">
              <span className="text-gray-400">Build Number</span>
              <span className="text-[#00FFA3]">Build 23</span>
            </div>
          </div>
        </section>

        {/* Cyberpunk Analytics Gauges */}
        {telemetryStats && (
          <section className="glass-panel rounded-2xl p-6 border border-white/10 bg-black/40 space-y-4">
            <div className="flex items-center justify-between border-b border-white/10 pb-3">
              <div className="flex items-center space-x-2">
                <BarChart3 className="w-4 h-4 text-[#00F0FF]" />
                <h3 className="font-bold text-sm text-white font-mono uppercase tracking-wider">
                  Live Telemetry &amp; System Health Matrix
                </h3>
              </div>
              <span className="text-xs font-mono text-gray-400">
                Total Events: <span className="text-[#00F0FF]">{telemetryStats.totalEvents}</span>
              </span>
            </div>

            <div className="grid grid-cols-2 sm:grid-cols-5 gap-4 pt-2">
              <div className="bg-black/60 p-3 rounded-xl border border-white/10">
                <span className="text-[10px] font-mono text-gray-400">CALCULATIONS</span>
                <p className="text-xl font-bold text-[#00FFA3] font-mono">
                  {telemetryStats.countsByType?.calculation || historyItems.length}
                </p>
                <div className="w-full bg-white/10 h-1.5 rounded-full mt-2 overflow-hidden">
                  <div className="bg-[#00FFA3] h-full" style={{ width: "85%" }} />
                </div>
              </div>

              <div className="bg-black/60 p-3 rounded-xl border border-white/10">
                <span className="text-[10px] font-mono text-gray-400">ACTIVE CLIENT DEVICES</span>
                <p className="text-xl font-bold text-cyan-400 font-mono">
                  {telemetryStats.uniqueDevicesCount || 3}
                </p>
                <div className="w-full bg-white/10 h-1.5 rounded-full mt-2 overflow-hidden">
                  <div className="bg-cyan-400 h-full" style={{ width: "65%" }} />
                </div>
              </div>

              <div className="bg-black/60 p-3 rounded-xl border border-white/10">
                <div className="flex items-center justify-between">
                  <span className="text-[10px] font-mono text-gray-400">ACTIVE SESSIONS</span>
                  <span className="relative flex h-2 w-2">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[#00F0FF] opacity-75"></span>
                    <span className="relative inline-flex rounded-full h-2 w-2 bg-[#00F0FF]"></span>
                  </span>
                </div>
                <p className="text-xl font-bold text-[#00F0FF] font-mono">
                  {health?.services?.auth_service?.activeSessions ?? (telemetryStats?.activeSessions || activeSessionsList.length || 1)}
                </p>
                <div className="w-full bg-white/10 h-1.5 rounded-full mt-2 overflow-hidden">
                  <div className="bg-[#00F0FF] h-full" style={{ width: "80%" }} />
                </div>
              </div>

              <div className="bg-black/60 p-3 rounded-xl border border-white/10">
                <span className="text-[10px] font-mono text-gray-400">PERFORMANCE LATENCY</span>
                <p className="text-xl font-bold text-purple-400 font-mono">
                  {telemetryStats.averagePerformanceLatencyMs}ms
                </p>
                <div className="w-full bg-white/10 h-1.5 rounded-full mt-2 overflow-hidden">
                  <div className="bg-purple-400 h-full" style={{ width: "45%" }} />
                </div>
              </div>

              <div className="bg-black/60 p-3 rounded-xl border border-white/10">
                <span className="text-[10px] font-mono text-gray-400">CRASH INCIDENCE</span>
                <p className="text-xl font-bold text-emerald-400 font-mono">
                  {telemetryStats.crashCount === 0 ? "0.00% (CLEAN)" : `${telemetryStats.crashRatePct}%`}
                </p>
                <div className="w-full bg-white/10 h-1.5 rounded-full mt-2 overflow-hidden">
                  <div
                    className={telemetryStats.crashCount === 0 ? "bg-emerald-400 h-full" : "bg-red-400 h-full"}
                    style={{ width: telemetryStats.crashCount === 0 ? "100%" : "25%" }}
                  />
                </div>
              </div>
            </div>
          </section>
        )}

        {/* Interactive Feature Sandboxes (Tabs) */}
        <section className="glass-panel rounded-2xl p-6 border border-white/10 bg-black/40 space-y-6">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 border-b border-white/10 pb-4">
            <div className="flex items-center space-x-3">
              <div className="p-2 rounded-lg bg-[#00F0FF]/10 border border-[#00F0FF]/30 text-[#00F0FF]">
                <Terminal className="w-5 h-5" />
              </div>
              <div>
                <h2 className="text-lg font-bold text-white flex items-center space-x-2">
                  <span>Interactive Serverless Feature Sandboxes</span>
                </h2>
                <p className="text-xs text-gray-400">
                  Directly test auth, real-time sync, AI streaming, OTA manifests, and crash logging
                </p>
              </div>
            </div>

            {/* Sandbox Tabs */}
            <div className="flex flex-wrap gap-1 bg-black/60 p-1.5 rounded-xl border border-white/10">
              {[
                { id: "ai", label: "AI Stream", icon: Sparkles },
                { id: "auth", label: "JWT & Device", icon: Lock },
                { id: "history", label: "Calculations", icon: Database },
                { id: "notes", label: "Math Notes", icon: BookOpen },
                { id: "ota", label: "iOS OTA Plist", icon: Smartphone },
                { id: "telemetry", label: "Telemetry", icon: Bug },
              ].map((tab) => {
                const Icon = tab.icon;
                return (
                  <button
                    key={tab.id}
                    onClick={() => setActiveTab(tab.id as any)}
                    className={`flex items-center space-x-1.5 px-3 py-1.5 rounded-lg text-xs font-mono transition-all ${
                      activeTab === tab.id
                        ? "bg-[#00F0FF] text-black font-semibold shadow-glowCyan"
                        : "text-gray-400 hover:text-white"
                    }`}
                  >
                    <Icon className="w-3.5 h-3.5" />
                    <span>{tab.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* TAB 1: AI STREAM */}
          {activeTab === "ai" && (
            <div className="space-y-4">
              <div className="flex flex-col md:flex-row gap-3">
                <input
                  type="text"
                  value={aiPrompt}
                  onChange={(e) => setAiPrompt(e.target.value)}
                  placeholder="Enter mathematical equation, calculus question, or physics formula..."
                  className="flex-1 bg-black/50 border border-white/15 rounded-xl px-4 py-3 text-sm text-white focus:outline-none focus:border-[#00F0FF] transition-all font-mono"
                />
                <button
                  onClick={handleStartStream}
                  disabled={aiStreaming || !aiPrompt.trim()}
                  className="inline-flex items-center justify-center space-x-2 px-6 py-3 rounded-xl bg-[#00F0FF] text-black font-semibold text-xs uppercase tracking-wider hover:bg-[#00d0de] disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-glowCyan"
                >
                  {aiStreaming ? (
                    <>
                      <RefreshCw className="w-4 h-4 animate-spin" />
                      <span>Streaming...</span>
                    </>
                  ) : (
                    <>
                      <Play className="w-4 h-4 fill-current" />
                      <span>Stream Answer</span>
                    </>
                  )}
                </button>
              </div>

              <div className="flex flex-wrap gap-2 text-xs font-mono">
                <span className="text-gray-500 py-1">Quick equations:</span>
                {[
                  "Evaluate integral of x * cos(x) dx",
                  "det([[3, 5], [2, 8]])",
                  "Factor 6x^2 + 11x - 35",
                  "Solve 3x + 4y = 20 and 2x - y = 6",
                ].map((suggestion, idx) => (
                  <button
                    key={idx}
                    onClick={() => setAiPrompt(suggestion)}
                    className="px-2.5 py-1 rounded-md bg-white/5 hover:bg-white/10 border border-white/10 text-gray-300 hover:text-[#00F0FF] transition-all"
                  >
                    {suggestion}
                  </button>
                ))}
              </div>

              <div className="relative rounded-xl bg-black/70 border border-white/15 p-4 font-mono text-xs text-gray-200 min-h-[160px] max-h-[350px] overflow-y-auto">
                <div className="sticky top-0 flex items-center justify-between pb-2 mb-2 border-b border-white/10 text-gray-400">
                  <div className="flex items-center space-x-2">
                    <span className="w-2.5 h-2.5 rounded-full bg-red-500/80 inline-block"></span>
                    <span className="w-2.5 h-2.5 rounded-full bg-yellow-500/80 inline-block"></span>
                    <span className="w-2.5 h-2.5 rounded-full bg-green-500/80 inline-block"></span>
                    <span className="text-[11px] ml-2 text-gray-400">POST /api/ai/stream stdout</span>
                  </div>
                  {aiOutput && (
                    <button
                      onClick={() => copyToClipboard(aiOutput, "streamOutput")}
                      className="flex items-center space-x-1 text-gray-400 hover:text-white"
                    >
                      <Copy className="w-3 h-3" />
                      <span>{copiedText === "streamOutput" ? "Copied!" : "Copy"}</span>
                    </button>
                  )}
                </div>

                {aiOutput ? (
                  <pre className="whitespace-pre-wrap leading-relaxed text-gray-200">
                    {aiOutput}
                    {aiStreaming && (
                      <span className="inline-block w-2 h-4 bg-[#00F0FF] animate-pulse ml-1 align-middle" />
                    )}
                  </pre>
                ) : (
                  <div className="text-gray-500 flex flex-col items-center justify-center h-28 space-y-2">
                    <Terminal className="w-6 h-6 text-gray-600" />
                    <span>Click &quot;Stream Answer&quot; to test real-time Server-Sent Events</span>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* TAB 2: AUTH & DEVICE TOKENS */}
          {activeTab === "auth" && (
            <div className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                <div>
                  <label className="block text-[11px] font-mono text-gray-400 mb-1">User Email</label>
                  <input
                    type="email"
                    value={authEmail}
                    onChange={(e) => setAuthEmail(e.target.value)}
                    className="w-full bg-black/60 border border-white/15 rounded-lg px-3 py-2 text-xs text-white font-mono focus:border-yellow-400 focus:outline-none"
                  />
                </div>
                <div>
                  <label className="block text-[11px] font-mono text-gray-400 mb-1">Password</label>
                  <input
                    type="password"
                    value={authPassword}
                    onChange={(e) => setAuthPassword(e.target.value)}
                    className="w-full bg-black/60 border border-white/15 rounded-lg px-3 py-2 text-xs text-white font-mono focus:border-yellow-400 focus:outline-none"
                  />
                </div>
                <div>
                  <label className="block text-[11px] font-mono text-gray-400 mb-1">Full Name</label>
                  <input
                    type="text"
                    value={authName}
                    onChange={(e) => setAuthName(e.target.value)}
                    className="w-full bg-black/60 border border-white/15 rounded-lg px-3 py-2 text-xs text-white font-mono focus:border-yellow-400 focus:outline-none"
                  />
                </div>
              </div>

              <div className="flex flex-wrap gap-2">
                <button
                  onClick={handleRegister}
                  disabled={authLoading}
                  className="px-4 py-2 rounded-lg bg-yellow-400 hover:bg-yellow-300 text-black font-semibold text-xs font-mono flex items-center space-x-1.5 transition-all"
                >
                  <User className="w-3.5 h-3.5" />
                  <span>Register Account</span>
                </button>
                <button
                  onClick={handleLogin}
                  disabled={authLoading}
                  className="px-4 py-2 rounded-lg bg-white/10 hover:bg-white/15 text-white font-semibold text-xs font-mono flex items-center space-x-1.5 border border-white/15 transition-all"
                >
                  <Lock className="w-3.5 h-3.5 text-yellow-400" />
                  <span>Login (Generate Token)</span>
                </button>
                <button
                  onClick={handleIssueDeviceToken}
                  disabled={authLoading}
                  className="px-4 py-2 rounded-lg bg-purple-500/20 hover:bg-purple-500/30 text-purple-300 font-semibold text-xs font-mono flex items-center space-x-1.5 border border-purple-500/30 transition-all"
                >
                  <Smartphone className="w-3.5 h-3.5" />
                  <span>Issue Mobile Device Token</span>
                </button>
                <button
                  onClick={() => testEndpoint("/api/auth/profile", "GET")}
                  className="px-4 py-2 rounded-lg bg-cyan-500/20 hover:bg-cyan-500/30 text-cyan-300 font-semibold text-xs font-mono flex items-center space-x-1.5 border border-cyan-500/30 transition-all"
                >
                  <Key className="w-3.5 h-3.5" />
                  <span>Verify Profile / Me</span>
                </button>
              </div>

              {authToken && (
                <div className="p-2.5 rounded-lg bg-yellow-500/10 border border-yellow-500/20 text-xs font-mono flex items-center justify-between">
                  <div className="truncate mr-2">
                    <span className="text-gray-400">Active Bearer Token: </span>
                    <span className="text-yellow-300">{authToken.substring(0, 48)}...</span>
                  </div>
                  <button
                    onClick={() => copyToClipboard(authToken, "authToken")}
                    className="shrink-0 px-2 py-1 rounded bg-yellow-500/20 text-yellow-300 text-[10px]"
                  >
                    {copiedText === "authToken" ? "Copied" : "Copy"}
                  </button>
                </div>
              )}

              {authOutput && (
                <div className="rounded-xl bg-black/70 border border-white/15 p-3 font-mono text-xs text-yellow-300/90 max-h-[180px] overflow-y-auto">
                  <pre>{authOutput}</pre>
                </div>
              )}
            </div>
          )}

          {/* TAB 3: CALCULATION HISTORY SYNC */}
          {activeTab === "history" && (
            <div className="space-y-4">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div className="flex flex-wrap gap-1 bg-black/40 p-1 rounded-xl border border-white/10">
                  {["all", "calculus", "matrix", "standard", "programmer", "converter", "receipt"].map(
                    (m) => (
                      <button
                        key={m}
                        onClick={() => {
                          setHistoryMode(m);
                          fetchHistory(m);
                        }}
                        className={`px-3 py-1 rounded-lg text-xs font-mono uppercase transition-all ${
                          historyMode === m
                            ? "bg-[#00FFA3] text-black font-semibold"
                            : "text-gray-400 hover:text-white"
                        }`}
                      >
                        {m}
                      </button>
                    )
                  )}
                </div>
                <span className="text-xs font-mono text-gray-400">
                  Sync Mode: <span className="text-[#00FFA3]">Bidirectional LWW</span>
                </span>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-12 gap-3 bg-black/40 p-3.5 rounded-xl border border-white/10 items-end">
                <div className="sm:col-span-5">
                  <label className="block text-[11px] font-mono text-gray-400 mb-1">Expression</label>
                  <input
                    type="text"
                    value={newExpr}
                    onChange={(e) => setNewExpr(e.target.value)}
                    className="w-full bg-black/60 border border-white/15 rounded-lg px-3 py-2 text-xs text-white font-mono focus:border-[#00FFA3] focus:outline-none"
                  />
                </div>
                <div className="sm:col-span-4">
                  <label className="block text-[11px] font-mono text-gray-400 mb-1">Result</label>
                  <input
                    type="text"
                    value={newResult}
                    onChange={(e) => setNewResult(e.target.value)}
                    className="w-full bg-black/60 border border-white/15 rounded-lg px-3 py-2 text-xs text-white font-mono focus:border-[#00FFA3] focus:outline-none"
                  />
                </div>
                <div className="sm:col-span-2">
                  <label className="block text-[11px] font-mono text-gray-400 mb-1">Mode</label>
                  <select
                    value={newMode}
                    onChange={(e) => setNewMode(e.target.value)}
                    className="w-full bg-black/60 border border-white/15 rounded-lg px-3 py-2 text-xs text-white font-mono focus:border-[#00FFA3] focus:outline-none"
                  >
                    <option value="calculus">calculus</option>
                    <option value="matrix">matrix</option>
                    <option value="standard">standard</option>
                    <option value="programmer">programmer</option>
                    <option value="converter">converter</option>
                  </select>
                </div>
                <div className="sm:col-span-1">
                  <button
                    onClick={handleAddHistoryItem}
                    className="w-full py-2 bg-[#00FFA3] hover:bg-[#00d88b] text-black font-semibold rounded-lg text-xs font-mono flex items-center justify-center transition-all"
                  >
                    <Send className="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>

              <div className="rounded-xl bg-black/70 border border-white/15 overflow-hidden max-h-[260px] overflow-y-auto">
                <table className="w-full text-left text-xs font-mono">
                  <thead className="bg-white/5 border-b border-white/10 text-gray-400 uppercase text-[10px]">
                    <tr>
                      <th className="px-4 py-2.5">Time</th>
                      <th className="px-4 py-2.5">Mode</th>
                      <th className="px-4 py-2.5">Expression</th>
                      <th className="px-4 py-2.5">Result</th>
                      <th className="px-4 py-2.5">Device</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/5">
                    {historyItems.map((item) => (
                      <tr key={item.id} className="hover:bg-white/[0.02]">
                        <td className="px-4 py-2.5 text-gray-400 text-[11px]">
                          {new Date(item.timestamp).toLocaleTimeString()}
                        </td>
                        <td className="px-4 py-2.5">
                          <span className="px-2 py-0.5 rounded bg-white/10 text-[#00F0FF] text-[10px] uppercase">
                            {item.mode}
                          </span>
                        </td>
                        <td className="px-4 py-2.5 text-white">{item.expression}</td>
                        <td className="px-4 py-2.5 text-[#00FFA3]">{item.result}</td>
                        <td className="px-4 py-2.5 text-gray-400 text-[11px]">{item.deviceId || "Seed"}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* TAB 4: MATH NOTES & NOTEBOOKS */}
          {activeTab === "notes" && (
            <div className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-12 gap-3 bg-black/40 p-4 rounded-xl border border-white/10">
                <div className="md:col-span-8 space-y-2">
                  <input
                    type="text"
                    value={newNoteTitle}
                    onChange={(e) => setNewNoteTitle(e.target.value)}
                    placeholder="Notebook title..."
                    className="w-full bg-black/60 border border-white/15 rounded-lg px-3 py-2 text-xs text-white font-mono focus:border-purple-400 focus:outline-none"
                  />
                  <textarea
                    rows={4}
                    value={newNoteMarkdown}
                    onChange={(e) => setNewNoteMarkdown(e.target.value)}
                    placeholder="Markdown note content with LaTeX formulas..."
                    className="w-full bg-black/60 border border-white/15 rounded-lg px-3 py-2 text-xs text-white font-mono focus:border-purple-400 focus:outline-none"
                  />
                </div>
                <div className="md:col-span-4 flex flex-col justify-between space-y-2">
                  <div>
                    <label className="block text-[11px] font-mono text-gray-400 mb-1">Tag</label>
                    <input
                      type="text"
                      value={newNoteTag}
                      onChange={(e) => setNewNoteTag(e.target.value)}
                      placeholder="e.g. calculus, study"
                      className="w-full bg-black/60 border border-white/15 rounded-lg px-3 py-2 text-xs text-white font-mono focus:border-purple-400 focus:outline-none"
                    />
                  </div>
                  <button
                    onClick={handleCreateNote}
                    className="w-full py-2.5 bg-purple-500 hover:bg-purple-600 text-white font-semibold rounded-lg text-xs font-mono flex items-center justify-center space-x-1.5 transition-all shadow-glowCyan"
                  >
                    <Plus className="w-4 h-4" />
                    <span>Sync Note to Cloud</span>
                  </button>
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                {notesItems.map((note) => (
                  <div key={note.id} className="p-4 rounded-xl bg-black/60 border border-white/10 space-y-2">
                    <div className="flex items-center justify-between">
                      <h4 className="font-semibold text-white text-sm truncate">{note.title}</h4>
                      <div className="flex gap-1">
                        {note.tags.map((t, idx) => (
                          <span key={idx} className="text-[10px] px-2 py-0.5 rounded bg-purple-500/10 text-purple-300 font-mono">
                            #{t}
                          </span>
                        ))}
                      </div>
                    </div>
                    <pre className="text-[11px] text-gray-300 font-mono line-clamp-3 whitespace-pre-wrap">
                      {note.markdown}
                    </pre>
                    <div className="text-[10px] text-gray-500 font-mono pt-2 border-t border-white/5 flex justify-between">
                      <span>Updated: {new Date(note.updatedAt).toLocaleDateString()}</span>
                      <span>{note.deviceId || "Device"}</span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* TAB 5: IOS OTA MANIFEST */}
          {activeTab === "ota" && (
            <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
              <div className="lg:col-span-5 space-y-3">
                <div>
                  <label className="block text-xs font-mono text-gray-400 mb-1">
                    Bundle Identifier (CFBundleIdentifier)
                  </label>
                  <input
                    type="text"
                    value={otaBundleId}
                    onChange={(e) => setOtaBundleId(e.target.value)}
                    className="w-full bg-black/50 border border-white/15 rounded-lg px-3 py-2 text-xs text-white font-mono focus:border-[#00F0FF] focus:outline-none"
                  />
                </div>
                <div>
                  <label className="block text-xs font-mono text-gray-400 mb-1">
                    Application Title (CFBundleDisplayName)
                  </label>
                  <input
                    type="text"
                    value={otaAppName}
                    onChange={(e) => setOtaAppName(e.target.value)}
                    className="w-full bg-black/50 border border-white/15 rounded-lg px-3 py-2 text-xs text-white font-mono focus:border-[#00F0FF] focus:outline-none"
                  />
                </div>
                <div>
                  <label className="block text-xs font-mono text-gray-400 mb-1">
                    Version (CFBundleShortVersionString)
                  </label>
                  <input
                    type="text"
                    value={otaVersion}
                    onChange={(e) => setOtaVersion(e.target.value)}
                    className="w-full bg-black/50 border border-white/15 rounded-lg px-3 py-2 text-xs text-white font-mono focus:border-[#00F0FF] focus:outline-none"
                  />
                </div>
                <div className="pt-2 space-y-1">
                  <label className="block text-xs font-mono text-gray-400">Wireless 1-Tap iOS Install URL</label>
                  <input
                    type="text"
                    readOnly
                    value={itmsUrl}
                    className="w-full bg-black/70 border border-purple-500/30 rounded-lg px-3 py-2 text-[11px] text-purple-300 font-mono select-all"
                  />
                </div>
              </div>

              <div className="lg:col-span-7">
                <div className="rounded-xl bg-black/70 border border-white/15 p-4 font-mono text-xs text-gray-300 flex flex-col h-full">
                  <div className="flex items-center justify-between pb-2 mb-2 border-b border-white/10 text-gray-400">
                    <div className="flex items-center space-x-2">
                      <FileCode2 className="w-4 h-4 text-purple-400" />
                      <span className="text-[11px]">manifest.plist preview</span>
                    </div>
                    <button
                      onClick={() => copyToClipboard(otaXmlPreview, "otaXml")}
                      className="flex items-center space-x-1 text-gray-400 hover:text-white"
                    >
                      <Copy className="w-3 h-3" />
                      <span>{copiedText === "otaXml" ? "Copied!" : "Copy"}</span>
                    </button>
                  </div>
                  <pre className="flex-1 overflow-x-auto overflow-y-auto max-h-[220px] text-[11px] text-emerald-400/90 leading-relaxed">
                    {otaXmlPreview || "Loading manifest..."}
                  </pre>
                </div>
              </div>
            </div>
          )}

          {/* TAB 6: TELEMETRY & CRASH REPORTING */}
          {activeTab === "telemetry" && (
            <div className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-12 gap-3 bg-black/40 p-4 rounded-xl border border-white/10">
                <div className="md:col-span-8">
                  <label className="block text-[11px] font-mono text-gray-400 mb-1">Simulate Crash Message</label>
                  <input
                    type="text"
                    value={crashMessage}
                    onChange={(e) => setCrashMessage(e.target.value)}
                    className="w-full bg-black/60 border border-white/15 rounded-lg px-3 py-2 text-xs text-white font-mono focus:border-red-400 focus:outline-none"
                  />
                </div>
                <div className="md:col-span-4 flex items-end gap-2">
                  <button
                    onClick={handleSendCrash}
                    disabled={sendingTelemetry}
                    className="flex-1 py-2 bg-red-500/20 hover:bg-red-500/30 text-red-300 font-semibold rounded-lg text-xs font-mono border border-red-500/30 transition-all"
                  >
                    Submit Crash Report
                  </button>
                  <button
                    onClick={handleSendPerf}
                    disabled={sendingTelemetry}
                    className="flex-1 py-2 bg-orange-500/20 hover:bg-orange-500/30 text-orange-300 font-semibold rounded-lg text-xs font-mono border border-orange-500/30 transition-all"
                  >
                    Log Perf Event
                  </button>
                </div>
              </div>

              <div className="rounded-xl bg-black/70 border border-white/15 p-3 max-h-[220px] overflow-y-auto font-mono text-xs">
                <div className="text-gray-400 text-[11px] pb-2 border-b border-white/10 mb-2">
                  Recent Telemetry Event Log Stream
                </div>
                {telemetryLogs.map((log) => (
                  <div key={log.id} className="py-1.5 flex items-center justify-between border-b border-white/5 text-[11px]">
                    <div className="flex items-center space-x-2">
                      <span className={`px-1.5 py-0.5 rounded text-[10px] uppercase ${
                        log.type === "crash" ? "bg-red-500/20 text-red-400" : "bg-cyan-500/20 text-cyan-400"
                      }`}>
                        {log.type}
                      </span>
                      <span className="text-white">{log.name}</span>
                    </div>
                    <span className="text-gray-500">{new Date(log.createdAt).toLocaleTimeString()}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </section>

        {/* Complete API Reference & Live Route Inspector */}
        <section className="glass-panel rounded-2xl p-6 border border-white/10 bg-black/40 space-y-6">
          <div className="flex items-center space-x-3 border-b border-white/10 pb-4">
            <div className="p-2 rounded-lg bg-[#FF007A]/10 border border-[#FF007A]/30 text-[#FF007A]">
              <Code className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-white">Full-Suite API Reference &amp; Live Route Inspector</h2>
              <p className="text-xs text-gray-400">
                Execute live requests against all Auth, Sync, AI, OTA, Telemetry, and Updates route handlers
              </p>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
            {/* Endpoints Table */}
            <div className="lg:col-span-7 space-y-2.5 max-h-[460px] overflow-y-auto pr-1">
              {[
                {
                  path: "/api/health",
                  method: "GET",
                  desc: "System status, uptime, version 2.3.0 & service telemetry",
                  badge: "GET",
                  action: () => testEndpoint("/api/health", "GET"),
                },
                {
                  path: "/api/auth/register",
                  method: "POST",
                  desc: "Register account with email, password & issue JWT tokens",
                  badge: "POST",
                  action: () =>
                    testEndpoint("/api/auth/register", "POST", {
                      email: `user_${Date.now()}@liquidcalc.local`,
                      password: "securepassword123",
                      name: "Test User",
                    }),
                },
                {
                  path: "/api/auth/login",
                  method: "POST",
                  desc: "Authenticate credentials & return access/refresh tokens",
                  badge: "POST",
                  action: () =>
                    testEndpoint("/api/auth/login", "POST", {
                      email: authEmail,
                      password: authPassword,
                    }),
                },
                {
                  path: "/api/auth/profile",
                  method: "GET",
                  desc: "Fetch authenticated user or device profile via JWT Bearer",
                  badge: "GET",
                  action: () => testEndpoint("/api/auth/profile", "GET"),
                },
                {
                  path: "/api/auth/device",
                  method: "POST",
                  desc: "Issue or register mobile client hardware device token",
                  badge: "POST",
                  action: () =>
                    testEndpoint("/api/auth/device", "POST", {
                      deviceId: "iPhone16,2_Sim",
                      platform: "ios",
                    }),
                },
                {
                  path: "/api/auth/device/verify",
                  method: "GET",
                  desc: "Verify mobile client hardware device token validity",
                  badge: "GET",
                  action: () => testEndpoint("/api/auth/device/verify", "GET"),
                },
                {
                  path: "/api/auth/sessions",
                  method: "GET",
                  desc: "List active unexpired user & mobile device sessions",
                  badge: "GET",
                  action: () => testEndpoint("/api/auth/sessions", "GET"),
                },
                {
                  path: "/api/auth/refresh",
                  method: "POST",
                  desc: "Refresh JWT access token using 30-day refresh token",
                  badge: "POST",
                  action: () =>
                    testEndpoint("/api/auth/refresh", "POST", {
                      refreshToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                    }),
                },
                {
                  path: "/api/auth/apikey",
                  method: "POST",
                  desc: "Issue programmatic API Key for client integration",
                  badge: "POST",
                  action: () =>
                    testEndpoint("/api/auth/apikey", "POST", {
                      name: "Production Client Key",
                    }),
                },
                {
                  path: "/api/history",
                  method: "GET",
                  desc: "Root calculation history retrieval and recording endpoint",
                  badge: "GET",
                  action: () => testEndpoint("/api/history?limit=5", "GET"),
                },
                {
                  path: "/api/history/list",
                  method: "GET",
                  desc: "Paginated calculation history retrieval with mode filter",
                  badge: "GET",
                  action: () => testEndpoint("/api/history/list?limit=5", "GET"),
                },
                {
                  path: "/api/history/sync",
                  method: "POST",
                  desc: "Bidirectional calculation history sync with LWW conflict resolution",
                  badge: "POST",
                  action: () =>
                    testEndpoint("/api/history/sync", "POST", {
                      deviceId: "Inspector-Client",
                      items: [
                        {
                          id: `calc_insp_${Date.now()}`,
                          expression: "log10(1000)",
                          result: "3",
                          mode: "scientific",
                        },
                      ],
                    }),
                },
                {
                  path: "/api/notes",
                  method: "GET",
                  desc: "Retrieve synchronized math notes & notebooks",
                  badge: "GET",
                  action: () => testEndpoint("/api/notes?limit=5", "GET"),
                },
                {
                  path: "/api/notes/sync",
                  method: "POST",
                  desc: "Bidirectional math notes sync with conflict resolution",
                  badge: "POST",
                  action: () =>
                    testEndpoint("/api/notes/sync", "POST", {
                      deviceId: "Inspector-Client",
                      notes: [
                        {
                          id: `note_insp_${Date.now()}`,
                          title: "Differential Forms",
                          markdown: "$$d(\\omega \\wedge \\eta) = d\\omega \\wedge \\eta + (-1)^p \\omega \\wedge d\\eta$$",
                          tags: ["calculus", "geometry"],
                          attachments: [],
                          updatedAt: new Date().toISOString(),
                        },
                      ],
                    }),
                },
                {
                  path: "/api/ai/solve",
                  method: "POST",
                  desc: "Structured JSON math solver & OCR analyzer",
                  badge: "POST",
                  action: () =>
                    testEndpoint("/api/ai/solve", "POST", {
                      mode: "math",
                      expression: "2x + 7 = 21",
                    }),
                },
                {
                  path: "/api/ota/manifest",
                  method: "GET",
                  desc: "Apple itms-services software-package XML plist",
                  badge: "GET",
                  action: () =>
                    testEndpoint(
                      "/api/ota/manifest?bundleId=com.liquidcalc.app&version=2.3.0",
                      "GET"
                    ),
                },
                {
                  path: "/api/ota/app",
                  method: "GET",
                  desc: "Binary download 302 redirect to latest IPA release",
                  badge: "GET",
                  action: () => testEndpoint("/api/ota/app", "GET"),
                },
                {
                  path: "/api/updates/check",
                  method: "GET",
                  desc: "Release v2.3.0 update check & changelog",
                  badge: "GET",
                  action: () => testEndpoint("/api/updates/check?currentVersion=1.2.0", "GET"),
                },
                {
                  path: "/api/telemetry/stats",
                  method: "GET",
                  desc: "Aggregated crash, performance & calculation telemetry",
                  badge: "GET",
                  action: () => testEndpoint("/api/telemetry/stats", "GET"),
                },
                {
                  path: "/api/telemetry/crash",
                  method: "POST",
                  desc: "Ingest iOS client crash report with stack trace",
                  badge: "POST",
                  action: () =>
                    testEndpoint("/api/telemetry/crash", "POST", {
                      error: "Simulated Inspector Exception",
                      deviceId: "Inspector-Device",
                    }),
                },
              ].map((route, i) => (
                <div
                  key={i}
                  className="glass-card rounded-xl p-3 border border-white/10 bg-black/40 flex items-center justify-between gap-3"
                >
                  <div className="flex items-center space-x-2.5 overflow-hidden">
                    <span
                      className={`text-[9px] font-mono font-bold px-1.5 py-0.5 rounded border ${
                        route.badge === "GET"
                          ? "bg-emerald-500/10 text-emerald-400 border-emerald-500/30"
                          : "bg-cyan-500/10 text-[#00F0FF] border-cyan-500/30"
                      }`}
                    >
                      {route.badge}
                    </span>
                    <div className="overflow-hidden">
                      <p className="font-mono text-xs font-semibold text-white truncate">
                        {route.path}
                      </p>
                      <p className="text-[11px] text-gray-400 truncate">{route.desc}</p>
                    </div>
                  </div>

                  <button
                    onClick={route.action}
                    className="shrink-0 px-2.5 py-1 rounded-lg bg-white/5 hover:bg-[#00F0FF] hover:text-black border border-white/10 text-xs font-mono text-gray-200 transition-all flex items-center space-x-1"
                  >
                    <Play className="w-3 h-3 fill-current" />
                    <span>Run</span>
                  </button>
                </div>
              ))}
            </div>

            {/* Live Inspector Box */}
            <div className="lg:col-span-5">
              <div className="rounded-xl bg-black/80 border border-white/15 p-4 font-mono text-xs text-gray-300 flex flex-col h-full min-h-[380px]">
                <div className="flex items-center justify-between pb-2 mb-2 border-b border-white/10 text-gray-400">
                  <div className="flex items-center space-x-2">
                    <Terminal className="w-4 h-4 text-[#00F0FF]" />
                    <span className="text-[11px] text-gray-300">
                      {selectedEndpoint || "inspector_response.json"}
                    </span>
                  </div>
                  {endpointResponse && (
                    <button
                      onClick={() => copyToClipboard(endpointResponse, "inspector")}
                      className="flex items-center space-x-1 text-gray-400 hover:text-white"
                    >
                      <Copy className="w-3 h-3" />
                      <span>{copiedText === "inspector" ? "Copied!" : "Copy"}</span>
                    </button>
                  )}
                </div>

                <div className="flex-1 overflow-x-auto overflow-y-auto max-h-[400px]">
                  {endpointTesting ? (
                    <div className="flex items-center justify-center h-full text-gray-500 space-x-2 py-24">
                      <RefreshCw className="w-4 h-4 animate-spin text-[#00F0FF]" />
                      <span>Executing request...</span>
                    </div>
                  ) : endpointResponse ? (
                    <pre className="text-[11px] text-[#00FFA3] leading-relaxed whitespace-pre-wrap">
                      {endpointResponse}
                    </pre>
                  ) : (
                    <div className="flex flex-col items-center justify-center h-full text-gray-500 py-24 space-y-2">
                      <Layers className="w-6 h-6 text-gray-600" />
                      <span>Click any &quot;Run&quot; button to view live HTTP response payload</span>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </section>
      </main>

      {/* Footer */}
      <footer className="max-w-7xl mx-auto px-6 pt-12 text-center text-xs font-mono text-gray-500 space-y-2">
        <div className="flex items-center justify-center space-x-4">
          <span>LiquidCalc iOS 18+</span>
          <span>•</span>
          <span>Next.js 14 Serverless Suite</span>
          <span>•</span>
          <span>SQLite Prisma ORM</span>
        </div>
        <p>© 2026 LiquidCalc Team. Engineered for high performance, zero-latency compute &amp; offline sync.</p>
      </footer>
    </div>
  );
}
