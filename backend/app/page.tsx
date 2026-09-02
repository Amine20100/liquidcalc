"use client";

import React, { useState, useEffect, useCallback } from "react";
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
  ExternalLink,
  Code,
  Layers,
  Send,
  Play,
  FileCode2,
  ShieldCheck,
  Smartphone,
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

export default function DashboardPage() {
  const [health, setHealth] = useState<HealthData | null>(null);
  const [loadingHealth, setLoadingHealth] = useState(true);

  // Gemini Stream Sandbox State
  const [aiPrompt, setAiPrompt] = useState(
    "Evaluate integral of (3x^2 + 2x) * e^x dx with step-by-step calculus derivation"
  );
  const [aiStreaming, setAiStreaming] = useState(false);
  const [aiOutput, setAiOutput] = useState("");
  const [streamChunksCount, setStreamChunksCount] = useState(0);

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
    fetchOtaPreview();
  }, [fetchHealth, fetchHistory, fetchOtaPreview]);

  // Handle SSE Stream Test
  const handleStartStream = async () => {
    if (!aiPrompt.trim() || aiStreaming) return;
    setAiStreaming(true);
    setAiOutput("");
    setStreamChunksCount(0);

    try {
      const res = await fetch("/api/ai/stream", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
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
              if (parsed.done) {
                // finished
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

  // Handle Sync Test Record
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

  // Handle Testing Any Endpoint
  const testEndpoint = async (path: string, method: string, body?: object) => {
    setSelectedEndpoint(path);
    setEndpointTesting(true);
    setEndpointResponse("Executing request...");

    try {
      const options: RequestInit = { method };
      if (body) {
        options.headers = { "Content-Type": "application/json" };
        options.body = JSON.stringify(body);
      }
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
    <div className="min-h-screen pb-20 cyber-grid">
      {/* Top Navbar */}
      <header className="sticky top-0 z-50 glass-panel border-b border-white/10 px-6 py-4">
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
                <span className="text-xs px-2 py-0.5 rounded-full bg-[#00F0FF]/10 text-[#00F0FF] border border-[#00F0FF]/30 font-mono">
                  v2.3.0 PROD
                </span>
              </div>
              <p className="text-xs text-gray-400 font-mono">
                Serverless Backend & Gemini 2.5 Flash Engine
              </p>
            </div>
          </div>

          <div className="flex items-center space-x-4">
            <div className="hidden sm:flex items-center space-x-2 px-3 py-1.5 rounded-lg bg-black/40 border border-white/10 text-xs font-mono">
              <Server className="w-3.5 h-3.5 text-[#7928CA]" />
              <span className="text-gray-400">Regions:</span>
              <span className="text-emerald-400">iad1 / cdg1</span>
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
        <section className="relative overflow-hidden rounded-2xl glass-panel p-8 border border-white/10">
          <div className="absolute -right-20 -top-20 w-80 h-80 bg-[#00F0FF]/10 rounded-full blur-3xl pointer-events-none" />
          <div className="absolute -left-20 -bottom-20 w-80 h-80 bg-[#7928CA]/15 rounded-full blur-3xl pointer-events-none" />

          <div className="relative z-10 flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
            <div className="space-y-3">
              <div className="inline-flex items-center space-x-2 px-3 py-1 rounded-md bg-[#00F0FF]/10 border border-[#00F0FF]/30 text-[#00F0FF] text-xs font-mono">
                <Zap className="w-3.5 h-3.5" />
                <span>Next.js 14/15 Edge & Node Serverless Hub</span>
              </div>
              <h1 className="text-3xl sm:text-4xl font-extrabold tracking-tight text-white">
                LiquidCalc <span className="text-transparent bg-clip-text bg-gradient-to-r from-[#00F0FF] via-[#7928CA] to-[#00FFA3]">Cloud Telemetry</span>
              </h1>
              <p className="text-sm text-gray-300 max-w-2xl leading-relaxed">
                Production-grade serverless suite providing real-time Google Gemini 2.5 Flash SSE streaming, dynamic Apple <code className="text-[#00F0FF] font-mono">itms-services</code> software-package OTA sideloading, v2.3.0 release distribution, and calculation record cloud synchronization.
              </p>
            </div>

            <div className="flex flex-col sm:flex-row gap-3 w-full md:w-auto">
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

        {/* 4 Telemetry Metrics Cards */}
        <section className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
          {/* Card 1: Gemini 2.5 Flash */}
          <div className="glass-card rounded-xl p-5 border border-white/10 flex flex-col justify-between space-y-4">
            <div className="flex items-center justify-between">
              <div className="w-10 h-10 rounded-lg bg-[#00F0FF]/10 border border-[#00F0FF]/30 flex items-center justify-center text-[#00F0FF]">
                <Cpu className="w-5 h-5" />
              </div>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                ACTIVE
              </span>
            </div>
            <div>
              <h3 className="font-semibold text-white text-base">Gemini 2.5 Flash</h3>
              <p className="text-xs text-gray-400 mt-1">
                SSE Streaming, Multimodal OCR & LaTeX solver
              </p>
            </div>
            <div className="pt-2 border-t border-white/10 flex items-center justify-between text-xs font-mono">
              <span className="text-gray-400">Model</span>
              <span className="text-[#00F0FF]">gemini-2.5-flash</span>
            </div>
          </div>

          {/* Card 2: iOS OTA Sideloading */}
          <div className="glass-card rounded-xl p-5 border border-white/10 flex flex-col justify-between space-y-4">
            <div className="flex items-center justify-between">
              <div className="w-10 h-10 rounded-lg bg-[#7928CA]/10 border border-[#7928CA]/30 flex items-center justify-center text-[#7928CA]">
                <Smartphone className="w-5 h-5 text-purple-400" />
              </div>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                READY
              </span>
            </div>
            <div>
              <h3 className="font-semibold text-white text-base">Apple itms-services</h3>
              <p className="text-xs text-gray-400 mt-1">
                Dynamic XML Plist manifest generator
              </p>
            </div>
            <div className="pt-2 border-t border-white/10 flex items-center justify-between text-xs font-mono">
              <span className="text-gray-400">DTD Specification</span>
              <span className="text-purple-400">Apple DTD 1.0</span>
            </div>
          </div>

          {/* Card 3: Version Distribution */}
          <div className="glass-card rounded-xl p-5 border border-white/10 flex flex-col justify-between space-y-4">
            <div className="flex items-center justify-between">
              <div className="w-10 h-10 rounded-lg bg-[#00FFA3]/10 border border-[#00FFA3]/30 flex items-center justify-center text-[#00FFA3]">
                <ShieldCheck className="w-5 h-5" />
              </div>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                LATEST
              </span>
            </div>
            <div>
              <h3 className="font-semibold text-white text-base">Distribution Hub</h3>
              <p className="text-xs text-gray-400 mt-1">
                GitHub Release & AltStore repository source
              </p>
            </div>
            <div className="pt-2 border-t border-white/10 flex items-center justify-between text-xs font-mono">
              <span className="text-gray-400">Target Release</span>
              <span className="text-[#00FFA3]">v2.3.0 (Build 23)</span>
            </div>
          </div>

          {/* Card 4: History Sync */}
          <div className="glass-card rounded-xl p-5 border border-white/10 flex flex-col justify-between space-y-4">
            <div className="flex items-center justify-between">
              <div className="w-10 h-10 rounded-lg bg-[#FF007A]/10 border border-[#FF007A]/30 flex items-center justify-center text-[#FF007A]">
                <Database className="w-5 h-5" />
              </div>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                SYNCED
              </span>
            </div>
            <div>
              <h3 className="font-semibold text-white text-base">Calculation Store</h3>
              <p className="text-xs text-gray-400 mt-1">
                UUID deduplication & multi-mode sync
              </p>
            </div>
            <div className="pt-2 border-t border-white/10 flex items-center justify-between text-xs font-mono">
              <span className="text-gray-400">Records</span>
              <span className="text-[#FF007A]">{health?.services?.history_sync?.recordsCount || historyItems.length} items</span>
            </div>
          </div>
        </section>

        {/* Interactive Gemini 2.5 Flash SSE Stream Sandbox */}
        <section className="glass-panel rounded-2xl p-6 border border-white/10 space-y-6">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 border-b border-white/10 pb-4">
            <div className="flex items-center space-x-3">
              <div className="p-2 rounded-lg bg-[#00F0FF]/10 border border-[#00F0FF]/30 text-[#00F0FF]">
                <Terminal className="w-5 h-5" />
              </div>
              <div>
                <h2 className="text-lg font-bold text-white flex items-center space-x-2">
                  <span>Gemini 2.5 Flash SSE Streaming Sandbox</span>
                  <span className="text-[10px] px-2 py-0.5 rounded bg-[#00F0FF]/10 text-[#00F0FF] border border-[#00F0FF]/30 font-mono">
                    POST /api/ai/stream
                  </span>
                </h2>
                <p className="text-xs text-gray-400">
                  Real-time Server-Sent Events chunk delivery with token stream parsing
                </p>
              </div>
            </div>

            <div className="flex items-center space-x-2 text-xs font-mono text-gray-400">
              <span>Chunks received:</span>
              <span className="text-[#00F0FF] font-bold">{streamChunksCount}</span>
            </div>
          </div>

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

            {/* Quick prompt suggestions */}
            <div className="flex flex-wrap gap-2 text-xs font-mono">
              <span className="text-gray-500 py-1">Try:</span>
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

            {/* Terminal Output Display */}
            <div className="relative rounded-xl bg-black/70 border border-white/15 p-4 font-mono text-xs text-gray-200 min-h-[160px] max-h-[350px] overflow-y-auto">
              <div className="sticky top-0 flex items-center justify-between pb-2 mb-2 border-b border-white/10 text-gray-400">
                <div className="flex items-center space-x-2">
                  <span className="w-2.5 h-2.5 rounded-full bg-red-500/80 inline-block"></span>
                  <span className="w-2.5 h-2.5 rounded-full bg-yellow-500/80 inline-block"></span>
                  <span className="w-2.5 h-2.5 rounded-full bg-green-500/80 inline-block"></span>
                  <span className="text-[11px] ml-2 text-gray-400">stream_stdout.log</span>
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
                  <span>Click &quot;Stream Answer&quot; to test real-time SSE token delivery</span>
                </div>
              )}
            </div>
          </div>
        </section>

        {/* Dynamic iOS OTA Manifest & Sideloading Hub */}
        <section className="glass-panel rounded-2xl p-6 border border-white/10 space-y-6">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 border-b border-white/10 pb-4">
            <div className="flex items-center space-x-3">
              <div className="p-2 rounded-lg bg-[#7928CA]/10 border border-[#7928CA]/30 text-[#7928CA]">
                <Smartphone className="w-5 h-5 text-purple-400" />
              </div>
              <div>
                <h2 className="text-lg font-bold text-white flex items-center space-x-2">
                  <span>Dynamic Apple itms-services OTA Manifest Hub</span>
                  <span className="text-[10px] px-2 py-0.5 rounded bg-purple-500/10 text-purple-400 border border-purple-500/30 font-mono">
                    GET /api/ota/manifest
                  </span>
                </h2>
                <p className="text-xs text-gray-400">
                  Dynamic software-package XML plist generator for 1-tap wireless sideloading
                </p>
              </div>
            </div>

            <button
              onClick={fetchOtaPreview}
              className="inline-flex items-center space-x-1.5 px-3 py-1.5 rounded-lg bg-white/5 hover:bg-white/10 border border-white/10 text-xs font-mono text-gray-300"
            >
              <RefreshCw className={`w-3.5 h-3.5 ${loadingOta ? "animate-spin" : ""}`} />
              <span>Regenerate Plist</span>
            </button>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
            <div className="lg:col-span-5 space-y-4">
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

              <div className="pt-2 space-y-2">
                <label className="block text-xs font-mono text-gray-400">
                  Wireless iOS 1-Tap Install URI
                </label>
                <div className="flex items-center space-x-2">
                  <input
                    type="text"
                    readOnly
                    value={itmsUrl}
                    className="flex-1 bg-black/70 border border-purple-500/30 rounded-lg px-3 py-2 text-[11px] text-purple-300 font-mono select-all focus:outline-none"
                  />
                  <button
                    onClick={() => copyToClipboard(itmsUrl, "itmsUrl")}
                    className="px-3 py-2 rounded-lg bg-purple-500/20 hover:bg-purple-500/30 border border-purple-500/40 text-purple-300 text-xs font-mono flex items-center space-x-1"
                  >
                    <Copy className="w-3.5 h-3.5" />
                    <span>{copiedText === "itmsUrl" ? "Copied!" : "Copy"}</span>
                  </button>
                </div>
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
        </section>

        {/* Calculation History & Cloud Sync Explorer */}
        <section className="glass-panel rounded-2xl p-6 border border-white/10 space-y-6">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 border-b border-white/10 pb-4">
            <div className="flex items-center space-x-3">
              <div className="p-2 rounded-lg bg-[#00FFA3]/10 border border-[#00FFA3]/30 text-[#00FFA3]">
                <Database className="w-5 h-5" />
              </div>
              <div>
                <h2 className="text-lg font-bold text-white flex items-center space-x-2">
                  <span>Calculation History &amp; Sync Engine</span>
                  <span className="text-[10px] px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/30 font-mono">
                    POST /api/history/sync
                  </span>
                </h2>
                <p className="text-xs text-gray-400">
                  Cloud backup, UUID deduplication, mode filtering, and paginated records
                </p>
              </div>
            </div>

            {/* Mode filter tabs */}
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
                        ? "bg-[#00FFA3] text-black font-semibold shadow-glowEmerald"
                        : "text-gray-400 hover:text-white"
                    }`}
                  >
                    {m}
                  </button>
                )
              )}
            </div>
          </div>

          {/* Quick sync test form */}
          <div className="grid grid-cols-1 sm:grid-cols-12 gap-3 bg-black/40 p-4 rounded-xl border border-white/10 items-end">
            <div className="sm:col-span-5">
              <label className="block text-[11px] font-mono text-gray-400 mb-1">
                Expression
              </label>
              <input
                type="text"
                value={newExpr}
                onChange={(e) => setNewExpr(e.target.value)}
                placeholder="e.g. integral(x^2 dx)"
                className="w-full bg-black/60 border border-white/15 rounded-lg px-3 py-2 text-xs text-white font-mono focus:border-[#00FFA3] focus:outline-none"
              />
            </div>
            <div className="sm:col-span-4">
              <label className="block text-[11px] font-mono text-gray-400 mb-1">
                Result
              </label>
              <input
                type="text"
                value={newResult}
                onChange={(e) => setNewResult(e.target.value)}
                placeholder="e.g. x^3 / 3 + C"
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
                <option value="receipt">receipt</option>
              </select>
            </div>
            <div className="sm:col-span-1">
              <button
                onClick={handleAddHistoryItem}
                className="w-full py-2 bg-[#00FFA3] hover:bg-[#00d88b] text-black font-semibold rounded-lg text-xs font-mono flex items-center justify-center transition-all shadow-glowEmerald"
                title="Sync Record to Server"
              >
                <Send className="w-3.5 h-3.5" />
              </button>
            </div>
          </div>

          {/* History items table */}
          <div className="rounded-xl bg-black/70 border border-white/15 overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs font-mono">
                <thead className="bg-white/5 border-b border-white/10 text-gray-400 uppercase text-[10px] tracking-wider">
                  <tr>
                    <th className="px-4 py-3">Timestamp</th>
                    <th className="px-4 py-3">Mode</th>
                    <th className="px-4 py-3">Expression</th>
                    <th className="px-4 py-3">Result</th>
                    <th className="px-4 py-3">Device / Notes</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-white/5">
                  {loadingHistory ? (
                    <tr>
                      <td colSpan={5} className="text-center py-6 text-gray-500">
                        Loading calculation records...
                      </td>
                    </tr>
                  ) : historyItems.length === 0 ? (
                    <tr>
                      <td colSpan={5} className="text-center py-6 text-gray-500">
                        No calculation records found in this category.
                      </td>
                    </tr>
                  ) : (
                    historyItems.map((item) => (
                      <tr key={item.id} className="hover:bg-white/[0.03] transition-colors">
                        <td className="px-4 py-3 text-gray-400 text-[11px] whitespace-nowrap">
                          {new Date(item.timestamp).toLocaleTimeString([], {
                            hour: "2-digit",
                            minute: "2-digit",
                            second: "2-digit",
                          })}
                        </td>
                        <td className="px-4 py-3">
                          <span className="px-2 py-0.5 rounded bg-white/10 text-[#00F0FF] text-[10px] uppercase">
                            {item.mode}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-white font-medium max-w-xs truncate">
                          {item.expression}
                        </td>
                        <td className="px-4 py-3 text-[#00FFA3] max-w-xs truncate">
                          {item.result}
                        </td>
                        <td className="px-4 py-3 text-gray-400 text-[11px] max-w-xs truncate">
                          {item.notes || item.deviceId || "—"}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </section>

        {/* Complete API Reference & Live Route Inspector */}
        <section className="glass-panel rounded-2xl p-6 border border-white/10 space-y-6">
          <div className="flex items-center space-x-3 border-b border-white/10 pb-4">
            <div className="p-2 rounded-lg bg-[#FF007A]/10 border border-[#FF007A]/30 text-[#FF007A]">
              <Code className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-white">API Reference &amp; Live Route Inspector</h2>
              <p className="text-xs text-gray-400">
                Execute live requests against any serverless route handler with immediate response inspection
              </p>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
            {/* Endpoints Table */}
            <div className="lg:col-span-7 space-y-3">
              {[
                {
                  path: "/api/health",
                  method: "GET",
                  desc: "System status, uptime, version 2.3.0 & service telemetry",
                  badge: "GET",
                  action: () => testEndpoint("/api/health", "GET"),
                },
                {
                  path: "/api/ai/stream",
                  method: "POST",
                  desc: "Gemini 2.5 Flash real-time SSE stream proxy",
                  badge: "POST",
                  action: () =>
                    testEndpoint("/api/ai/stream", "POST", {
                      prompt: "Compute 15% tip on $128.50 bill",
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
                  path: "/api/updates/latest",
                  method: "GET",
                  desc: "GitHub & AltStore release metadata",
                  badge: "GET",
                  action: () => testEndpoint("/api/updates/latest", "GET"),
                },
                {
                  path: "/api/history/list",
                  method: "GET",
                  desc: "Paginated calculation history retrieval",
                  badge: "GET",
                  action: () => testEndpoint("/api/history/list?limit=5", "GET"),
                },
                {
                  path: "/api/history/sync",
                  method: "POST",
                  desc: "Batch sync & backup calculation records",
                  badge: "POST",
                  action: () =>
                    testEndpoint("/api/history/sync", "POST", {
                      items: [
                        {
                          id: `test_${Date.now()}`,
                          expression: "sqrt(144) + 10",
                          result: "22",
                          mode: "standard",
                        },
                      ],
                    }),
                },
              ].map((route, i) => (
                <div
                  key={i}
                  className="glass-card rounded-xl p-3.5 border border-white/10 flex items-center justify-between gap-4"
                >
                  <div className="flex items-center space-x-3 overflow-hidden">
                    <span
                      className={`text-[10px] font-mono font-bold px-2 py-0.5 rounded border ${
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
                    className="shrink-0 px-3 py-1.5 rounded-lg bg-white/5 hover:bg-[#00F0FF] hover:text-black border border-white/10 text-xs font-mono text-gray-200 transition-all flex items-center space-x-1"
                  >
                    <Play className="w-3 h-3 fill-current" />
                    <span>Test</span>
                  </button>
                </div>
              ))}
            </div>

            {/* Live Inspector Box */}
            <div className="lg:col-span-5">
              <div className="rounded-xl bg-black/80 border border-white/15 p-4 font-mono text-xs text-gray-300 flex flex-col h-full min-h-[360px]">
                <div className="flex items-center justify-between pb-2 mb-2 border-b border-white/10 text-gray-400">
                  <div className="flex items-center space-x-2">
                    <Terminal className="w-4 h-4 text-[#00F0FF]" />
                    <span className="text-[11px] text-gray-300">
                      {selectedEndpoint || "inspector_output.json"}
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

                <div className="flex-1 overflow-x-auto overflow-y-auto max-h-[380px]">
                  {endpointTesting ? (
                    <div className="flex items-center justify-center h-full text-gray-500 space-x-2 py-20">
                      <RefreshCw className="w-4 h-4 animate-spin text-[#00F0FF]" />
                      <span>Executing request...</span>
                    </div>
                  ) : endpointResponse ? (
                    <pre className="text-[11px] text-[#00FFA3] leading-relaxed whitespace-pre-wrap">
                      {endpointResponse}
                    </pre>
                  ) : (
                    <div className="flex flex-col items-center justify-center h-full text-gray-500 py-20 space-y-2">
                      <Layers className="w-6 h-6 text-gray-600" />
                      <span>Select any &quot;Test&quot; button to view live HTTP response</span>
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
          <span>Swift 6 Pure Native</span>
          <span>•</span>
          <span>Next.js Serverless Suite</span>
        </div>
        <p>© 2026 LiquidCalc Team. Engineered for high performance &amp; zero-latency compute.</p>
      </footer>
    </div>
  );
}
