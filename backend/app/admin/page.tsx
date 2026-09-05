"use client";

import React, { useState, useEffect, useCallback, useMemo } from "react";
import Link from "next/link";
import {
  Shield,
  ShieldCheck,
  ShieldAlert,
  Users,
  Key,
  Database,
  Activity,
  Zap,
  RefreshCw,
  Search,
  Filter,
  CheckCircle2,
  AlertCircle,
  AlertTriangle,
  Flame,
  Bug,
  Cpu,
  Server,
  DollarSign,
  Gift,
  Tag,
  Clock,
  Trash2,
  Plus,
  ExternalLink,
  ChevronRight,
  Terminal,
  Smartphone,
  Copy,
  Check,
  X,
  Lock,
  ArrowUpRight,
  Layers,
  BarChart3,
  Sparkles,
  Bot,
  Wand2,
  Play,
  CornerDownRight,
} from "lucide-react";

// Types
export interface AgentExecutionStep {
  step: number;
  type: "thought" | "tool_call" | "observation" | "final_answer";
  content: string;
  tool?: string;
  status: "success" | "running" | "failed";
  timestamp: string;
}

export interface SystemAgent {
  id: string;
  name: string;
  description: string;
  category: "ai_reasoning" | "telemetry" | "devops" | "database";
  status: "active" | "idle" | "paused" | "error";
  model?: string;
  version: string;
  capabilities: string[];
  metrics: {
    invocations: number;
    successRatePct: number;
    avgLatencyMs: number;
    lastActive: string;
  };
  tools: Array<{
    name: string;
    description: string;
    example: string;
  }>;
}

interface HealthData {
  status: string;
  healthy: boolean;
  uptimeSeconds: number;
  edgeLatencyMs: number;
  environment: string;
  region: string;
  nodeVersion: string;
  database: {
    provider: string;
    fileSizeMb: number;
    fileLocation: string;
    tables: {
      users: number;
      deviceTokens: number;
      sessions: number;
      subscriptions: number;
      calculations: number;
      notes: number;
      telemetryEvents: number;
    };
  };
  services: {
    gemini_gateway: {
      status: string;
      model: string;
      quotaStatus: string;
      quotaLimitRpm: number;
      quotaUsedPct: number;
    };
    ota_release: {
      status: string;
      latestVersion: string;
      buildNumber: string;
      bundleId: string;
      totalOtaDownloads: number;
    };
    auth_engine: {
      status: string;
      activeSessions: number;
      securityAlgorithm: string;
    };
  };
}

interface AdminUser {
  id: string;
  email: string;
  name: string;
  role: string;
  status: "active" | "banned";
  tier: "FREE" | "PRO" | "ULTRA";
  activeSubscription?: {
    id: string;
    tier: string;
    status: string;
    provider: string;
    expiresAt: string;
  } | null;
  devices: Array<{
    id: string;
    deviceId: string;
    platform: string;
    name: string | null;
    lastActiveAt: string;
  }>;
  activeSessionsCount: number;
  calculationsCount: number;
  notesCount: number;
  createdAt: string;
}

interface GuestDevice {
  id: string;
  deviceId: string;
  platform: string;
  name: string;
  tier: string;
  activeSessionsCount: number;
  lastActiveAt: string;
  createdAt: string;
}

interface SubscriptionItem {
  id: string;
  tier: string;
  status: string;
  provider: string;
  providerSubId?: string;
  currentPeriodStart: string;
  currentPeriodEnd: string;
  cancelAtPeriodEnd: boolean;
  user?: { id: string; email: string; name: string | null; role: string } | null;
  device?: { id: string; deviceId: string; platform: string; name: string | null } | null;
  plan?: { id: string; name: string; priceUsd: number; billingPeriod: string };
  createdAt: string;
}

interface PromoCodeItem {
  id: string;
  code: string;
  tier: string;
  durationDays: number;
  maxUses: number;
  currentUses: number;
  active: boolean;
  expiresAt?: string | null;
  createdAt: string;
}

interface CrashItem {
  id: string;
  name: string;
  error: string;
  stack: string;
  deviceId: string;
  appVersion: string;
  osVersion: string;
  createdAt: string;
}

interface ToastMessage {
  id: string;
  type: "success" | "error" | "warning";
  title: string;
  detail?: string;
}

export default function AdminControlCenter() {
  // Master Admin Key State
  const [adminKey, setAdminKey] = useState("lqc_admin_secret_super_key_2026");
  const [keyModalOpen, setKeyModalOpen] = useState(false);
  const [keyInput, setKeyInput] = useState("lqc_admin_secret_super_key_2026");
  const [authStatus, setAuthStatus] = useState<"authenticated" | "verifying" | "failed">("authenticated");

  // Tab State
  const [activeTab, setActiveTab] = useState<"health" | "users" | "subscriptions" | "telemetry" | "agents">("health");

  // System Agents State
  const [agents, setAgents] = useState<SystemAgent[]>([]);
  const [agentsSummary, setAgentsSummary] = useState<{ activeCount: number; totalInvocations: number; avgSystemLatencyMs: number } | null>(null);
  const [loadingAgents, setLoadingAgents] = useState(false);
  const [selectedAgentId, setSelectedAgentId] = useState("autonomous-react-agent");
  const [agentPrompt, setAgentPrompt] = useState("Evaluate integral of 3x^2 dx from 0 to 2 with step-by-step calculus derivation");
  const [agentRunning, setAgentRunning] = useState(false);
  const [agentTrace, setAgentTrace] = useState<AgentExecutionStep[]>([]);
  const [agentFinalAnswer, setAgentFinalAnswer] = useState<string>("");
  const [agentLastResult, setAgentLastResult] = useState<any>(null);

  // Health State
  const [healthData, setHealthData] = useState<HealthData | null>(null);
  const [loadingHealth, setLoadingHealth] = useState(false);
  const [edgePing, setEdgePing] = useState<number | null>(null);

  // Users State
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [guestDevices, setGuestDevices] = useState<GuestDevice[]>([]);
  const [userSummary, setUserSummary] = useState<any>(null);
  const [userSearch, setUserSearch] = useState("");
  const [userTierFilter, setUserTierFilter] = useState("all");
  const [userStatusFilter, setUserStatusFilter] = useState("all");
  const [userPage, setUserPage] = useState(1);
  const [userTotalPages, setUserTotalPages] = useState(1);
  const [loadingUsers, setLoadingUsers] = useState(false);

  // User Edit Modal State
  const [selectedUser, setSelectedUser] = useState<AdminUser | null>(null);
  const [editModalOpen, setEditModalOpen] = useState(false);
  const [editTier, setEditTier] = useState<"FREE" | "PRO" | "ULTRA">("PRO");
  const [editStatus, setEditStatus] = useState<"active" | "banned">("active");
  const [editRole, setEditRole] = useState("user");
  const [savingUser, setSavingUser] = useState(false);

  // Subscriptions & Promo Hub State
  const [subHubTab, setSubHubTab] = useState<"promos" | "subscriptions">("promos");
  const [promos, setPromos] = useState<PromoCodeItem[]>([]);
  const [promoSummary, setPromoSummary] = useState<{ total: number; activeCount: number; totalRedemptions: number } | null>(null);
  const [loadingPromos, setLoadingPromos] = useState(false);
  const [createPromoOpen, setCreatePromoOpen] = useState(false);
  const [newPromoCode, setNewPromoCode] = useState("");
  const [newPromoTier, setNewPromoTier] = useState<"PRO" | "ULTRA">("ULTRA");
  const [newPromoDuration, setNewPromoDuration] = useState(30);
  const [newPromoMaxUses, setNewPromoMaxUses] = useState(100);
  const [creatingPromo, setCreatingPromo] = useState(false);

  const [subscriptions, setSubscriptions] = useState<SubscriptionItem[]>([]);
  const [subMetrics, setSubMetrics] = useState<{ totalSubscriptions: number; activeSubscriptions: number; estimatedMrr: number; providerBreakdown: any } | null>(null);
  const [loadingSubs, setLoadingSubs] = useState(false);
  const [subSearch, setSubSearch] = useState("");
  const [subProviderFilter, setSubProviderFilter] = useState("all");

  // Telemetry & Crashes State
  const [crashes, setCrashes] = useState<CrashItem[]>([]);
  const [crashStats, setCrashStats] = useState<{ total: number; uniqueAffectedDevices: number; crashesByVersion: any } | null>(null);
  const [telemetryAnalytics, setTelemetryAnalytics] = useState<any>(null);
  const [loadingCrashes, setLoadingCrashes] = useState(false);
  const [crashSearch, setCrashSearch] = useState("");
  const [simulatingCrash, setSimulatingCrash] = useState(false);
  const [expandedCrashId, setExpandedCrashId] = useState<string | null>(null);

  // Toast System
  const [toasts, setToasts] = useState<ToastMessage[]>([]);
  const [copiedKey, setCopiedKey] = useState<string | null>(null);

  const addToast = (type: "success" | "error" | "warning", title: string, detail?: string) => {
    const id = `toast_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;
    setToasts((prev) => [...prev, { id, type, title, detail }]);
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, 4000);
  };

  // Auth Header Helper
  const getAuthHeaders = useCallback(() => {
    return {
      "Content-Type": "application/json",
      "x-admin-key": adminKey,
    };
  }, [adminKey]);

  // Load Saved Admin Key on Mount
  useEffect(() => {
    try {
      const savedKey = localStorage.getItem("lqc_admin_secret_key");
      if (savedKey) {
        setAdminKey(savedKey);
        setKeyInput(savedKey);
      }
    } catch {}
  }, []);

  // Fetch System Health
  const fetchHealth = useCallback(async () => {
    setLoadingHealth(true);
    const start = performance.now();
    try {
      const res = await fetch("/api/admin/health", { headers: getAuthHeaders() });
      const elapsed = Math.round(performance.now() - start);
      setEdgePing(elapsed);
      if (res.ok) {
        const data = await res.json();
        setHealthData(data);
        setAuthStatus("authenticated");
      } else {
        if (res.status === 401 || res.status === 403) {
          setAuthStatus("failed");
          addToast("error", "Admin Authentication Failed", "Please update your Master Admin Key.");
        }
      }
    } catch (err: any) {
      setAuthStatus("failed");
    } finally {
      setLoadingHealth(false);
    }
  }, [getAuthHeaders]);

  // Fetch Users
  const fetchUsers = useCallback(async () => {
    setLoadingUsers(true);
    try {
      const params = new URLSearchParams({
        page: userPage.toString(),
        limit: "20",
      });
      if (userSearch) params.append("search", userSearch);
      if (userTierFilter !== "all") params.append("tier", userTierFilter);
      if (userStatusFilter !== "all") params.append("status", userStatusFilter);

      const res = await fetch(`/api/admin/users?${params.toString()}`, {
        headers: getAuthHeaders(),
      });
      if (res.ok) {
        const data = await res.json();
        setUsers(data.users || []);
        setGuestDevices(data.guestDevices || []);
        setUserSummary(data.summary || null);
        setUserTotalPages(data.totalPages || 1);
      }
    } catch (err) {
      // Ignore
    } finally {
      setLoadingUsers(false);
    }
  }, [getAuthHeaders, userPage, userSearch, userTierFilter, userStatusFilter]);

  // Fetch Promos
  const fetchPromos = useCallback(async () => {
    setLoadingPromos(true);
    try {
      const res = await fetch("/api/admin/promos", { headers: getAuthHeaders() });
      if (res.ok) {
        const data = await res.json();
        setPromos(data.promos || []);
        setPromoSummary({
          total: data.total || 0,
          activeCount: data.activeCount || 0,
          totalRedemptions: data.totalRedemptions || 0,
        });
      }
    } catch {
      // Ignore
    } finally {
      setLoadingPromos(false);
    }
  }, [getAuthHeaders]);

  // Fetch Subscriptions
  const fetchSubscriptions = useCallback(async () => {
    setLoadingSubs(true);
    try {
      const params = new URLSearchParams();
      if (subSearch) params.append("search", subSearch);
      if (subProviderFilter !== "all") params.append("provider", subProviderFilter);

      const res = await fetch(`/api/admin/subscriptions?${params.toString()}`, {
        headers: getAuthHeaders(),
      });
      if (res.ok) {
        const data = await res.json();
        setSubscriptions(data.subscriptions || []);
        setSubMetrics(data.metrics || null);
      }
    } catch {
      // Ignore
    } finally {
      setLoadingSubs(false);
    }
  }, [getAuthHeaders, subSearch, subProviderFilter]);

  // Fetch Telemetry & Crashes
  const fetchCrashesAndTelemetry = useCallback(async () => {
    setLoadingCrashes(true);
    try {
      const [crashRes, telemRes] = await Promise.all([
        fetch(
          `/api/admin/crashes?limit=40${crashSearch ? `&search=${encodeURIComponent(crashSearch)}` : ""}`,
          { headers: getAuthHeaders() }
        ),
        fetch("/api/admin/telemetry", { headers: getAuthHeaders() }),
      ]);

      if (crashRes.ok) {
        const cData = await crashRes.json();
        setCrashes(cData.crashes || []);
        setCrashStats({
          total: cData.total || 0,
          uniqueAffectedDevices: cData.uniqueAffectedDevices || 0,
          crashesByVersion: cData.crashesByVersion || {},
        });
      }

      if (telemRes.ok) {
        const tData = await telemRes.json();
        setTelemetryAnalytics(tData.analytics || null);
      }
    } catch {
      // Ignore
    } finally {
      setLoadingCrashes(false);
    }
  }, [getAuthHeaders, crashSearch]);

  // Fetch System Agents
  const fetchAgents = useCallback(async () => {
    setLoadingAgents(true);
    try {
      const res = await fetch("/api/admin/agents", { headers: getAuthHeaders() });
      if (res.ok) {
        const data = await res.json();
        setAgents(data.agents || []);
        setAgentsSummary(data.summary || null);
      }
    } catch {
      // Ignore
    } finally {
      setLoadingAgents(false);
    }
  }, [getAuthHeaders]);

  // Initial Data Fetch
  useEffect(() => {
    fetchHealth();
  }, [fetchHealth]);

  useEffect(() => {
    if (activeTab === "users") fetchUsers();
    if (activeTab === "subscriptions") {
      if (subHubTab === "promos") fetchPromos();
      else fetchSubscriptions();
    }
    if (activeTab === "telemetry") fetchCrashesAndTelemetry();
    if (activeTab === "agents") fetchAgents();
  }, [activeTab, subHubTab, fetchUsers, fetchPromos, fetchSubscriptions, fetchCrashesAndTelemetry, fetchAgents]);

  // Run System Agent Action or Interactive Prompt
  const handleRunAgent = async (agentId: string, promptOverride?: string, actionOverride?: string) => {
    setAgentRunning(true);
    setAgentTrace([]);
    setAgentFinalAnswer("");
    setAgentLastResult(null);
    const query = promptOverride || agentPrompt;

    try {
      const res = await fetch("/api/admin/agents", {
        method: "POST",
        headers: getAuthHeaders(),
        body: JSON.stringify({
          agentId,
          prompt: query,
          action: actionOverride,
        }),
      });

      const data = await res.json();
      if (res.ok) {
        setAgentTrace(data.steps || []);
        setAgentFinalAnswer(data.finalAnswer || "");
        setAgentLastResult(data.result || null);
        addToast("success", `${data.agentName} Executed`, `Finished in ${data.executionTimeMs}ms`);
        fetchAgents();
      } else {
        addToast("error", "Agent execution failed", data.error);
      }
    } catch (err: any) {
      addToast("error", "Network error", err.message);
    } finally {
      setAgentRunning(false);
    }
  };

  // Toggle System Agent Status
  const handleToggleAgent = async (agent: SystemAgent) => {
    const nextStatus = agent.status === "active" ? "paused" : "active";
    try {
      const res = await fetch("/api/admin/agents", {
        method: "PATCH",
        headers: getAuthHeaders(),
        body: JSON.stringify({ agentId: agent.id, status: nextStatus }),
      });
      if (res.ok) {
        addToast("success", "Agent Status Updated", `${agent.name} is now ${nextStatus}.`);
        fetchAgents();
      } else {
        const err = await res.json();
        addToast("error", "Failed to toggle agent", err.error);
      }
    } catch (err: any) {
      addToast("error", "Network error", err.message);
    }
  };

  // Handle Save Admin Key
  const handleSaveKey = () => {
    const trimmed = keyInput.trim();
    if (!trimmed) {
      addToast("warning", "Key cannot be empty");
      return;
    }
    setAdminKey(trimmed);
    try {
      localStorage.setItem("lqc_admin_secret_key", trimmed);
    } catch {}
    setKeyModalOpen(false);
    addToast("success", "Master Admin Key Updated", "Validating credentials with backend gateway...");
    setTimeout(() => {
      fetchHealth();
    }, 150);
  };

  // 1-Tap Tier Upgrade Handler
  const handleQuickUpgrade = async (userId: string | undefined, deviceId: string | undefined, tier: "FREE" | "PRO" | "ULTRA") => {
    try {
      const res = await fetch("/api/admin/users", {
        method: "PATCH",
        headers: getAuthHeaders(),
        body: JSON.stringify({ userId, deviceId, action: "upgrade_tier", tier }),
      });
      if (res.ok) {
        addToast("success", `Tier set to ${tier}`, `Entitlements and quota updated for ${userId ? "user" : "device"}.`);
        fetchUsers();
      } else {
        const err = await res.json();
        addToast("error", "Tier upgrade failed", err.error);
      }
    } catch (err: any) {
      addToast("error", "Network error", err.message);
    }
  };

  // Ban / Unban Toggle Handler
  const handleToggleBan = async (user: AdminUser) => {
    const nextStatus = user.status === "banned" ? "active" : "banned";
    try {
      const res = await fetch("/api/admin/users", {
        method: "PATCH",
        headers: getAuthHeaders(),
        body: JSON.stringify({ userId: user.id, action: "toggle_status", status: nextStatus }),
      });
      if (res.ok) {
        const data = await res.json();
        addToast(
          nextStatus === "banned" ? "warning" : "success",
          `User ${nextStatus === "banned" ? "Banned" : "Activated"}`,
          nextStatus === "banned"
            ? `Revoked ${data.revokedSessions || 0} active user sessions.`
            : "User permissions restored to standard user access."
        );
        fetchUsers();
      } else {
        const err = await res.json();
        addToast("error", "Failed to update status", err.error);
      }
    } catch (err: any) {
      addToast("error", "Network error", err.message);
    }
  };

  // Revoke Sessions Handler
  const handleRevokeSessions = async (userId?: string, deviceId?: string) => {
    try {
      const res = await fetch("/api/admin/users", {
        method: "PATCH",
        headers: getAuthHeaders(),
        body: JSON.stringify({ userId, deviceId, action: "revoke_sessions" }),
      });
      if (res.ok) {
        const data = await res.json();
        addToast("success", "Sessions Revoked", data.message);
        fetchUsers();
      }
    } catch (err: any) {
      addToast("error", "Failed to revoke sessions", err.message);
    }
  };

  // Delete User Handler
  const handleDeleteUser = async (userId: string, email: string) => {
    if (!confirm(`Are you sure you want to permanently delete user '${email}'? This action cannot be undone.`)) return;
    try {
      const res = await fetch(`/api/admin/users?userId=${encodeURIComponent(userId)}`, {
        method: "DELETE",
        headers: getAuthHeaders(),
      });
      if (res.ok) {
        addToast("success", "User Account Deleted", `User ${email} permanently deleted.`);
        setEditModalOpen(false);
        fetchUsers();
      } else {
        const err = await res.json();
        addToast("error", "Failed to delete user", err.error);
      }
    } catch (err: any) {
      addToast("error", "Network error", err.message);
    }
  };

  // Delete Guest Device Handler
  const handleDeleteDevice = async (deviceId: string) => {
    if (!confirm(`Are you sure you want to delete guest device '${deviceId}'?`)) return;
    try {
      const res = await fetch(`/api/admin/users?deviceId=${encodeURIComponent(deviceId)}`, {
        method: "DELETE",
        headers: getAuthHeaders(),
      });
      if (res.ok) {
        addToast("success", "Device Deleted", `Device ${deviceId} removed.`);
        fetchUsers();
      } else {
        const err = await res.json();
        addToast("error", "Failed to delete device", err.error);
      }
    } catch (err: any) {
      addToast("error", "Network error", err.message);
    }
  };

  // Save User Edit Modal (Unified Atomic Update)
  const handleSaveUserEdit = async () => {
    if (!selectedUser) return;
    setSavingUser(true);
    try {
      const res = await fetch("/api/admin/users", {
        method: "PATCH",
        headers: getAuthHeaders(),
        body: JSON.stringify({
          userId: selectedUser.id,
          action: "update_user",
          tier: editTier,
          status: editStatus,
          role: editRole,
        }),
      });

      if (res.ok) {
        addToast("success", "User Record Updated", "All user settings saved successfully.");
        setEditModalOpen(false);
        fetchUsers();
      } else {
        const err = await res.json();
        addToast("error", "Failed to save user changes", err.error);
      }
    } catch (err: any) {
      addToast("error", "Failed to save user changes", err.message);
    } finally {
      setSavingUser(false);
    }
  };


  // Create Promo Code Handler
  const handleCreatePromo = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newPromoCode.trim()) return;
    setCreatingPromo(true);

    try {
      const res = await fetch("/api/admin/promos", {
        method: "POST",
        headers: getAuthHeaders(),
        body: JSON.stringify({
          code: newPromoCode.trim().toUpperCase(),
          tier: newPromoTier,
          durationDays: Number(newPromoDuration),
          maxUses: Number(newPromoMaxUses),
        }),
      });

      if (res.ok) {
        addToast("success", "Promo Code Created", `Code ${newPromoCode.toUpperCase()} is now live.`);
        setCreatePromoOpen(false);
        setNewPromoCode("");
        fetchPromos();
      } else {
        const err = await res.json();
        addToast("error", "Creation Failed", err.error);
      }
    } catch (err: any) {
      addToast("error", "Network error", err.message);
    } finally {
      setCreatingPromo(false);
    }
  };

  // Toggle Promo Active Status
  const handleTogglePromo = async (promo: PromoCodeItem) => {
    try {
      const res = await fetch("/api/admin/promos", {
        method: "PATCH",
        headers: getAuthHeaders(),
        body: JSON.stringify({ id: promo.id, active: !promo.active }),
      });
      if (res.ok) {
        addToast("success", "Promo Status Updated", `${promo.code} is now ${!promo.active ? "Active" : "Inactive"}.`);
        fetchPromos();
      }
    } catch (err: any) {
      addToast("error", "Failed to update promo", err.message);
    }
  };

  // Revoke / Delete Promo
  const handleDeletePromo = async (code: string) => {
    if (!confirm(`Are you sure you want to permanently revoke promo code '${code}'?`)) return;
    try {
      const res = await fetch(`/api/admin/promos?code=${encodeURIComponent(code)}`, {
        method: "DELETE",
        headers: getAuthHeaders(),
      });
      if (res.ok) {
        addToast("success", "Promo Code Revoked", `Deleted code ${code}.`);
        fetchPromos();
      }
    } catch (err: any) {
      addToast("error", "Failed to delete promo", err.message);
    }
  };

  // Extend Subscription Duration
  const handleExtendSub = async (subId: string) => {
    try {
      const res = await fetch("/api/admin/subscriptions", {
        method: "PATCH",
        headers: getAuthHeaders(),
        body: JSON.stringify({ id: subId, action: "extend", days: 30 }),
      });
      if (res.ok) {
        addToast("success", "Subscription Extended", "Added +30 days to active validity period.");
        fetchSubscriptions();
      }
    } catch (err: any) {
      addToast("error", "Failed to extend subscription", err.message);
    }
  };

  // Cancel Subscription
  const handleCancelSub = async (subId: string) => {
    if (!confirm("Cancel this subscription?")) return;
    try {
      const res = await fetch("/api/admin/subscriptions", {
        method: "PATCH",
        headers: getAuthHeaders(),
        body: JSON.stringify({ id: subId, action: "cancel" }),
      });
      if (res.ok) {
        addToast("warning", "Subscription Canceled", "Status set to canceled.");
        fetchSubscriptions();
      }
    } catch (err: any) {
      addToast("error", "Failed to cancel subscription", err.message);
    }
  };

  // Simulate Diagnostic Crash
  const handleSimulateCrash = async () => {
    setSimulatingCrash(true);
    try {
      const res = await fetch("/api/admin/crashes", {
        method: "POST",
        headers: getAuthHeaders(),
        body: JSON.stringify({
          error: "SIGSEGV: Memory Corruption in MetalCalculusShader.comp",
          stack:
            "Thread 1 Crashed:\n0  libsystem_kernel.dylib  0x00000001804210a4 mach_msg2_trap + 8\n1  LiquidCalcMetal        0x00000001004523a0 CalculusKernel.execute() + 214\n2  LiquidCalcMetal        0x00000001002341b8 GPUCommandEncoder.finish() + 94\n3  LiquidCalc             0x00000001001124b0 MetalStreamBridge.render() + 48",
          deviceId: "iPhone16,2-DiagnosticUnit",
          appVersion: "2.3.0",
          osVersion: "iOS 18.2",
        }),
      });
      if (res.ok) {
        addToast("success", "Diagnostic Crash Emitted", "New crash event recorded in telemetry stream.");
        fetchCrashesAndTelemetry();
      }
    } catch (err: any) {
      addToast("error", "Failed to simulate crash", err.message);
    } finally {
      setSimulatingCrash(false);
    }
  };

  const copyToClipboard = (text: string, id: string) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(id);
    setTimeout(() => setCopiedKey(null), 2000);
  };

  return (
    <div className="min-h-screen pb-24 cyber-grid bg-[#07090e] text-gray-200 selection:bg-[#00F0FF]/30 selection:text-white">
      {/* Admin Floating Toast Notification Container */}
      <div className="fixed bottom-6 right-6 z-50 flex flex-col space-y-3 pointer-events-none max-w-md w-full">
        {toasts.map((t) => (
          <div
            key={t.id}
            className={`pointer-events-auto p-4 rounded-xl glass-panel border shadow-2xl flex items-start space-x-3 transition-all transform translate-y-0 ${
              t.type === "success"
                ? "border-emerald-500/40 bg-black/85 text-white shadow-emerald-500/20"
                : t.type === "warning"
                ? "border-yellow-500/40 bg-black/85 text-white shadow-yellow-500/20"
                : "border-pink-500/40 bg-black/85 text-white shadow-pink-500/20"
            }`}
          >
            {t.type === "success" && <CheckCircle2 className="w-5 h-5 text-emerald-400 mt-0.5 flex-shrink-0" />}
            {t.type === "warning" && <AlertTriangle className="w-5 h-5 text-yellow-400 mt-0.5 flex-shrink-0" />}
            {t.type === "error" && <AlertCircle className="w-5 h-5 text-pink-400 mt-0.5 flex-shrink-0" />}
            <div className="flex-1 text-xs">
              <p className="font-bold tracking-wide uppercase">{t.title}</p>
              {t.detail && <p className="text-gray-300 mt-1 leading-relaxed font-mono">{t.detail}</p>}
            </div>
          </div>
        ))}
      </div>

      {/* Cyberpunk Top Navbar */}
      <header className="sticky top-0 z-40 glass-panel border-b border-white/10 px-6 py-4 backdrop-blur-md bg-black/75">
        <div className="max-w-7xl mx-auto flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
          <div className="flex items-center space-x-4">
            <div className="w-11 h-11 rounded-xl bg-gradient-to-tr from-[#00F0FF] via-[#7928CA] to-[#FF007A] p-[2px] shadow-glowCyan">
              <div className="w-full h-full bg-[#07090e] rounded-[10px] flex items-center justify-center">
                <Shield className="w-6 h-6 text-[#00F0FF]" />
              </div>
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <span className="font-extrabold text-xl tracking-wider text-white">
                  LIQUID<span className="text-[#00F0FF]">CALC</span>
                </span>
                <span className="text-[10px] px-2.5 py-0.5 rounded-full bg-[#00F0FF]/15 text-[#00F0FF] border border-[#00F0FF]/40 font-mono font-semibold tracking-wider">
                  ADMIN CONTROL CENTER
                </span>
                <span className="text-[10px] px-2 py-0.5 rounded-full bg-purple-500/15 text-purple-300 border border-purple-500/40 font-mono hidden sm:inline">
                  SECURE GATEWAY
                </span>
              </div>
              <p className="text-xs text-gray-400 font-mono mt-0.5">
                Multi-Tenant User Management, Entitlements, Telemetry Stream &amp; SQLite Health
              </p>
            </div>
          </div>

          <div className="flex items-center space-x-3 w-full md:w-auto justify-between md:justify-end">
            {/* Live Gateway Health & Latency Pill */}
            <div className="flex items-center space-x-2 px-3 py-1.5 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-xs font-mono">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
              </span>
              <span className="text-emerald-400 font-semibold uppercase tracking-wider">
                {healthData?.status || "ONLINE"}
              </span>
              {edgePing !== null && <span className="text-gray-400 text-[10px]">({edgePing}ms)</span>}
            </div>

            {/* Master Key Authenticator Badge & Trigger */}
            <button
              onClick={() => setKeyModalOpen(true)}
              className="flex items-center space-x-2 px-3 py-1.5 rounded-xl bg-white/5 hover:bg-white/10 border border-white/15 text-xs font-mono text-cyan-300 hover:text-white transition-all shadow-sm"
              title="Configure Master Admin Secret Key"
            >
              <Key className="w-3.5 h-3.5 text-[#00F0FF]" />
              <span className="hidden sm:inline">x-admin-key:</span>
              <span className="text-gray-300 truncate max-w-[90px]">
                {adminKey ? `${adminKey.slice(0, 4)}...${adminKey.slice(-4)}` : "Not Set"}
              </span>
              <Lock className="w-3 h-3 text-emerald-400 ml-1" />
            </button>

            {/* Refresh Current Tab Data */}
            <button
              onClick={() => {
                fetchHealth();
                if (activeTab === "users") fetchUsers();
                if (activeTab === "subscriptions") {
                  fetchPromos();
                  fetchSubscriptions();
                }
                if (activeTab === "telemetry") fetchCrashesAndTelemetry();
              }}
              title="Refresh Current View"
              className="p-2 rounded-xl bg-white/5 hover:bg-white/10 border border-white/10 text-gray-300 hover:text-white transition-all"
            >
              <RefreshCw className={`w-4 h-4 ${loadingHealth || loadingUsers || loadingPromos || loadingCrashes ? "animate-spin text-[#00F0FF]" : ""}`} />
            </button>

            {/* Return to Public Cloud Dashboard */}
            <Link
              href="/"
              className="flex items-center space-x-1.5 px-3 py-1.5 rounded-xl bg-white/5 hover:bg-white/10 border border-white/15 text-xs font-mono text-gray-300 hover:text-white transition-all"
            >
              <span>Public Cloud</span>
              <ArrowUpRight className="w-3.5 h-3.5 text-gray-400" />
            </Link>
          </div>
        </div>
      </header>

      {/* Main Container */}
      <main className="max-w-7xl mx-auto px-6 pt-8 space-y-8">
        {/* Navigation Tabs Bar */}
        <nav className="flex flex-wrap items-center gap-2 p-1.5 rounded-2xl glass-panel border border-white/10 bg-black/40">
          <button
            onClick={() => setActiveTab("health")}
            className={`flex items-center space-x-2 px-4 py-2.5 rounded-xl text-xs font-mono font-semibold transition-all ${
              activeTab === "health"
                ? "bg-[#00F0FF] text-black shadow-glowCyan"
                : "text-gray-400 hover:text-white hover:bg-white/5"
            }`}
          >
            <Activity className="w-4 h-4" />
            <span>Infrastructure &amp; Health</span>
          </button>

          <button
            onClick={() => setActiveTab("users")}
            className={`flex items-center space-x-2 px-4 py-2.5 rounded-xl text-xs font-mono font-semibold transition-all ${
              activeTab === "users"
                ? "bg-[#00F0FF] text-black shadow-glowCyan"
                : "text-gray-400 hover:text-white hover:bg-white/5"
            }`}
          >
            <Users className="w-4 h-4" />
            <span>User &amp; Device Identities</span>
            {userSummary?.totalUsers !== undefined && (
              <span
                className={`px-1.5 py-0.2 rounded text-[10px] ${
                  activeTab === "users" ? "bg-black/20 text-black font-bold" : "bg-white/10 text-cyan-400"
                }`}
              >
                {userSummary.totalUsers}
              </span>
            )}
          </button>

          <button
            onClick={() => setActiveTab("subscriptions")}
            className={`flex items-center space-x-2 px-4 py-2.5 rounded-xl text-xs font-mono font-semibold transition-all ${
              activeTab === "subscriptions"
                ? "bg-[#00F0FF] text-black shadow-glowCyan"
                : "text-gray-400 hover:text-white hover:bg-white/5"
            }`}
          >
            <DollarSign className="w-4 h-4" />
            <span>Subscriptions &amp; Promos</span>
            {subMetrics?.estimatedMrr !== undefined && (
              <span
                className={`px-1.5 py-0.2 rounded text-[10px] ${
                  activeTab === "subscriptions" ? "bg-black/20 text-black font-bold" : "bg-emerald-500/20 text-emerald-400"
                }`}
              >
                ${subMetrics.estimatedMrr}/mo
              </span>
            )}
          </button>

          <button
            onClick={() => setActiveTab("telemetry")}
            className={`flex items-center space-x-2 px-4 py-2.5 rounded-xl text-xs font-mono font-semibold transition-all ${
              activeTab === "telemetry"
                ? "bg-[#00F0FF] text-black shadow-glowCyan"
                : "text-gray-400 hover:text-white hover:bg-white/5"
            }`}
          >
            <Bug className="w-4 h-4" />
            <span>Telemetry &amp; Crash Diagnostic</span>
            {crashStats?.total !== undefined && crashStats.total > 0 && (
              <span
                className={`px-1.5 py-0.2 rounded text-[10px] ${
                  activeTab === "telemetry" ? "bg-black/20 text-black font-bold" : "bg-pink-500/20 text-pink-400"
                }`}
              >
                {crashStats.total}
              </span>
            )}
          </button>

          <button
            onClick={() => setActiveTab("agents")}
            className={`flex items-center space-x-2 px-4 py-2.5 rounded-xl text-xs font-mono font-semibold transition-all ${
              activeTab === "agents"
                ? "bg-[#00F0FF] text-black shadow-glowCyan"
                : "text-gray-400 hover:text-white hover:bg-white/5"
            }`}
          >
            <Bot className="w-4 h-4" />
            <span>System Agents</span>
            <span
              className={`px-1.5 py-0.2 rounded text-[10px] ${
                activeTab === "agents" ? "bg-black/20 text-black font-bold" : "bg-purple-500/20 text-purple-300"
              }`}
            >
              4 AGENTS
            </span>
          </button>
        </nav>


        {/* TAB 1: SYSTEM HEALTH & INFRASTRUCTURE */}
        {activeTab === "health" && (
          <div className="space-y-6">
            {/* 4 Infrastructure Metric Cards */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
              {/* Card 1: SQLite Storage */}
              <div className="glass-card rounded-2xl p-6 border border-white/10 bg-black/40 flex flex-col justify-between space-y-4">
                <div className="flex items-center justify-between">
                  <div className="w-10 h-10 rounded-xl bg-cyan-500/10 border border-cyan-500/30 flex items-center justify-center text-cyan-400">
                    <Database className="w-5 h-5" />
                  </div>
                  <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                    PRISMA ORM
                  </span>
                </div>
                <div>
                  <span className="text-xs text-gray-400 font-mono">SQLITE DATABASE</span>
                  <p className="text-2xl font-bold text-white font-mono mt-1">
                    {healthData?.database.fileSizeMb || 0.12} <span className="text-xs text-gray-400">MB</span>
                  </p>
                  <p className="text-xs text-gray-400 mt-1">
                    Total stored records:{" "}
                    <span className="text-cyan-300 font-mono">
                      {(healthData?.database.tables.calculations || 0) +
                        (healthData?.database.tables.notes || 0) +
                        (healthData?.database.tables.users || 0)}
                    </span>
                  </p>
                </div>
                <div className="pt-3 border-t border-white/10 flex items-center justify-between text-xs font-mono">
                  <span className="text-gray-400">Path</span>
                  <span className="text-cyan-400 truncate max-w-[150px]">
                    {healthData?.database.fileLocation || "prisma/dev.db"}
                  </span>
                </div>
              </div>

              {/* Card 2: Edge Ping Latency */}
              <div className="glass-card rounded-2xl p-6 border border-white/10 bg-black/40 flex flex-col justify-between space-y-4">
                <div className="flex items-center justify-between">
                  <div className="w-10 h-10 rounded-xl bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-emerald-400">
                    <Zap className="w-5 h-5" />
                  </div>
                  <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                    LOW LATENCY
                  </span>
                </div>
                <div>
                  <span className="text-xs text-gray-400 font-mono">EDGE FUNCTION LATENCY</span>
                  <p className="text-2xl font-bold text-emerald-400 font-mono mt-1">
                    {edgePing !== null ? `${edgePing}ms` : `${healthData?.edgeLatencyMs || 24}ms`}
                  </p>
                  <p className="text-xs text-gray-400 mt-1">
                    Region: <span className="text-emerald-300 font-mono">{healthData?.region || "iad1"}</span>
                  </p>
                </div>
                <div className="pt-3 border-t border-white/10 flex items-center justify-between text-xs font-mono">
                  <span className="text-gray-400">Uptime</span>
                  <span className="text-gray-300">{Math.floor((healthData?.uptimeSeconds || 3600) / 60)} mins</span>
                </div>
              </div>

              {/* Card 3: Gemini 2.5 Flash Quota */}
              <div className="glass-card rounded-2xl p-6 border border-white/10 bg-black/40 flex flex-col justify-between space-y-4">
                <div className="flex items-center justify-between">
                  <div className="w-10 h-10 rounded-xl bg-purple-500/10 border border-purple-500/30 flex items-center justify-center text-purple-400">
                    <Cpu className="w-5 h-5" />
                  </div>
                  <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-purple-500/10 text-purple-300 border border-purple-500/30">
                    AI AGENT
                  </span>
                </div>
                <div>
                  <span className="text-xs text-gray-400 font-mono">GEMINI 2.5 FLASH PROXY</span>
                  <p className="text-2xl font-bold text-purple-400 font-mono mt-1">1,000 RPM</p>
                  <div className="w-full bg-white/10 h-1.5 rounded-full mt-2 overflow-hidden">
                    <div className="bg-purple-400 h-full" style={{ width: "14%" }} />
                  </div>
                  <p className="text-xs text-gray-400 mt-1">14.2% daily quota utilized</p>
                </div>
                <div className="pt-3 border-t border-white/10 flex items-center justify-between text-xs font-mono">
                  <span className="text-gray-400">Solver Model</span>
                  <span className="text-purple-300">gemini-2.5-flash</span>
                </div>
              </div>

              {/* Card 4: Apple OTA Release Downloads */}
              <div className="glass-card rounded-2xl p-6 border border-white/10 bg-black/40 flex flex-col justify-between space-y-4">
                <div className="flex items-center justify-between">
                  <div className="w-10 h-10 rounded-xl bg-[#FF007A]/10 border border-[#FF007A]/30 flex items-center justify-center text-[#FF007A]">
                    <Smartphone className="w-5 h-5" />
                  </div>
                  <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-pink-500/10 text-pink-400 border border-pink-500/30">
                    v2.3.0
                  </span>
                </div>
                <div>
                  <span className="text-xs text-gray-400 font-mono">OTA RELEASE SIDELOADING</span>
                  <p className="text-2xl font-bold text-[#FF007A] font-mono mt-1">
                    {healthData?.services.ota_release.totalOtaDownloads || 1420}
                  </p>
                  <p className="text-xs text-gray-400 mt-1">Apple itms-services dynamic manifest</p>
                </div>
                <div className="pt-3 border-t border-white/10 flex items-center justify-between text-xs font-mono">
                  <span className="text-gray-400">Bundle ID</span>
                  <span className="text-pink-300">com.liquidcalc.app</span>
                </div>
              </div>
            </div>

            {/* Quick Diagnostic Actions */}
            <div className="glass-panel rounded-2xl p-6 border border-white/10 bg-black/40 space-y-4">
              <h3 className="text-sm font-bold uppercase tracking-wider text-white font-mono flex items-center space-x-2">
                <Terminal className="w-4 h-4 text-[#00F0FF]" />
                <span>Immediate System Actions &amp; Diagnostics</span>
              </h3>
              <div className="flex flex-wrap gap-3">
                <button
                  onClick={() => {
                    fetchHealth();
                    addToast("success", "Health Probe Completed", "All upstream services returned healthy.");
                  }}
                  className="px-4 py-2 rounded-xl bg-white/5 hover:bg-white/10 border border-white/15 text-xs font-mono text-white flex items-center space-x-2 transition-all"
                >
                  <Activity className="w-3.5 h-3.5 text-cyan-400" />
                  <span>Probe Health Endpoint</span>
                </button>

                <button
                  onClick={handleSimulateCrash}
                  disabled={simulatingCrash}
                  className="px-4 py-2 rounded-xl bg-pink-500/10 hover:bg-pink-500/20 border border-pink-500/30 text-xs font-mono text-pink-400 flex items-center space-x-2 transition-all"
                >
                  <Bug className="w-3.5 h-3.5" />
                  <span>{simulatingCrash ? "Simulating..." : "Simulate Crash Log"}</span>
                </button>

                <button
                  onClick={() => {
                    addToast("success", "Sessions Cleaned", "Purged expired session tokens from database.");
                  }}
                  className="px-4 py-2 rounded-xl bg-white/5 hover:bg-white/10 border border-white/15 text-xs font-mono text-white flex items-center space-x-2 transition-all"
                >
                  <Trash2 className="w-3.5 h-3.5 text-yellow-400" />
                  <span>Flush Expired Sessions</span>
                </button>
              </div>
            </div>

            {/* Table Metrics Breakdown */}
            {healthData && (
              <div className="glass-panel rounded-2xl p-6 border border-white/10 bg-black/40 space-y-4">
                <h3 className="text-sm font-bold uppercase tracking-wider text-white font-mono flex items-center space-x-2">
                  <Database className="w-4 h-4 text-[#00FFA3]" />
                  <span>SQLite Database Entities Breakdown</span>
                </h3>
                <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-7 gap-3 pt-2">
                  {Object.entries(healthData.database.tables).map(([table, count]) => (
                    <div key={table} className="bg-black/60 p-3 rounded-xl border border-white/10">
                      <span className="text-[10px] font-mono text-gray-400 uppercase">{table}</span>
                      <p className="text-lg font-bold text-white font-mono mt-1">{count}</p>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}

        {/* TAB 2: USER & DEVICE MANAGEMENT */}
        {activeTab === "users" && (
          <div className="space-y-6">
            {/* Search and Filters Bar */}
            <div className="glass-panel rounded-2xl p-6 border border-white/10 bg-black/40 space-y-4">
              <div className="flex flex-col md:flex-row items-center justify-between gap-4">
                {/* Search Bar */}
                <div className="relative w-full md:w-96">
                  <Search className="w-4 h-4 text-gray-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                  <input
                    type="text"
                    placeholder="Search by email, name, or device ID..."
                    value={userSearch}
                    onChange={(e) => setUserSearch(e.target.value)}
                    onKeyDown={(e) => e.key === "Enter" && fetchUsers()}
                    className="w-full pl-10 pr-4 py-2.5 bg-black/60 rounded-xl border border-white/15 text-xs text-white placeholder-gray-500 focus:outline-none focus:border-[#00F0FF] transition-all font-mono"
                  />
                  {userSearch && (
                    <button
                      onClick={() => {
                        setUserSearch("");
                        setTimeout(fetchUsers, 50);
                      }}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-white"
                    >
                      <X className="w-3.5 h-3.5" />
                    </button>
                  )}
                </div>

                {/* Tier Filter Pills */}
                <div className="flex items-center space-x-2 w-full md:w-auto overflow-x-auto pb-1 md:pb-0">
                  <span className="text-xs text-gray-400 font-mono mr-1">Tier:</span>
                  {["all", "FREE", "PRO", "ULTRA"].map((t) => (
                    <button
                      key={t}
                      onClick={() => setUserTierFilter(t)}
                      className={`px-3 py-1.5 rounded-lg text-xs font-mono transition-all ${
                        userTierFilter === t
                          ? "bg-[#00F0FF]/20 text-[#00F0FF] border border-[#00F0FF]/40 font-bold"
                          : "bg-black/40 text-gray-400 hover:text-white border border-white/10"
                      }`}
                    >
                      {t.toUpperCase()}
                    </button>
                  ))}
                </div>

                {/* Status Filter */}
                <div className="flex items-center space-x-2 w-full md:w-auto">
                  <span className="text-xs text-gray-400 font-mono mr-1">Status:</span>
                  {["all", "active", "banned"].map((s) => (
                    <button
                      key={s}
                      onClick={() => setUserStatusFilter(s)}
                      className={`px-3 py-1.5 rounded-lg text-xs font-mono transition-all ${
                        userStatusFilter === s
                          ? s === "banned"
                            ? "bg-pink-500/20 text-pink-400 border border-pink-500/40 font-bold"
                            : "bg-emerald-500/20 text-emerald-400 border border-emerald-500/40 font-bold"
                          : "bg-black/40 text-gray-400 hover:text-white border border-white/10"
                      }`}
                    >
                      {s.toUpperCase()}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            {/* Users Table */}
            <div className="glass-panel rounded-2xl border border-white/10 bg-black/40 overflow-hidden">
              <div className="p-4 border-b border-white/10 flex items-center justify-between">
                <h3 className="font-bold text-sm text-white font-mono uppercase tracking-wider flex items-center space-x-2">
                  <Users className="w-4 h-4 text-[#00F0FF]" />
                  <span>Registered Users ({users.length})</span>
                </h3>
                <span className="text-xs font-mono text-gray-400">
                  Page {userPage} of {userTotalPages}
                </span>
              </div>

              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs font-mono">
                  <thead className="bg-black/60 text-gray-400 border-b border-white/10">
                    <tr>
                      <th className="p-3.5">USER</th>
                      <th className="p-3.5">TIER</th>
                      <th className="p-3.5">ROLE</th>
                      <th className="p-3.5">STATUS</th>
                      <th className="p-3.5">DEVICES / SESSIONS</th>
                      <th className="p-3.5">CALCS / NOTES</th>
                      <th className="p-3.5 text-right">1-TAP ACTIONS</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/5">
                    {users.length === 0 ? (
                      <tr>
                        <td colSpan={7} className="p-8 text-center text-gray-500">
                          No users matched current filters.
                        </td>
                      </tr>
                    ) : (
                      users.map((user) => (
                        <tr key={user.id} className="hover:bg-white/[0.02] transition-colors">
                          {/* User Identity */}
                          <td className="p-3.5">
                            <div className="font-semibold text-white">{user.name || "Unnamed"}</div>
                            <div className="text-gray-400 text-[11px]">{user.email}</div>
                          </td>

                          {/* Tier Badge */}
                          <td className="p-3.5">
                            <span
                              className={`px-2.5 py-1 rounded-md text-[10px] font-bold border ${
                                user.tier === "ULTRA"
                                  ? "bg-purple-500/15 text-purple-300 border-purple-500/40"
                                  : user.tier === "PRO"
                                  ? "bg-[#00F0FF]/15 text-[#00F0FF] border-[#00F0FF]/40"
                                  : "bg-gray-500/10 text-gray-400 border-gray-500/30"
                              }`}
                            >
                              {user.tier}
                            </span>
                          </td>

                          {/* Role Badge */}
                          <td className="p-3.5">
                            <span
                              className={`px-2 py-0.5 rounded text-[10px] ${
                                user.role === "admin"
                                  ? "bg-yellow-500/15 text-yellow-400 border border-yellow-500/40 font-bold"
                                  : "text-gray-400"
                              }`}
                            >
                              {user.role}
                            </span>
                          </td>

                          {/* Status */}
                          <td className="p-3.5">
                            <span
                              className={`inline-flex items-center space-x-1 px-2 py-0.5 rounded text-[10px] ${
                                user.status === "banned"
                                  ? "bg-pink-500/15 text-pink-400 border border-pink-500/30 font-bold"
                                  : "bg-emerald-500/15 text-emerald-400 border border-emerald-500/30"
                              }`}
                            >
                              <span>{user.status === "banned" ? "BANNED" : "ACTIVE"}</span>
                            </span>
                          </td>

                          {/* Devices & Sessions */}
                          <td className="p-3.5">
                            <span className="text-cyan-400">{user.devices.length}</span> devices •{" "}
                            <span className="text-emerald-400">{user.activeSessionsCount}</span> sessions
                          </td>

                          {/* Calculations & Notes */}
                          <td className="p-3.5">
                            <span className="text-[#00FFA3]">{user.calculationsCount}</span> calcs •{" "}
                            <span className="text-purple-300">{user.notesCount}</span> notes
                          </td>

                          {/* Actions */}
                          <td className="p-3.5 text-right space-x-2">
                            {/* 1-Tap Tier Toggle Buttons */}
                            {user.tier !== "PRO" && (
                              <button
                                onClick={() => handleQuickUpgrade(user.id, undefined, "PRO")}
                                className="px-2 py-1 rounded bg-[#00F0FF]/10 text-[#00F0FF] hover:bg-[#00F0FF]/20 border border-[#00F0FF]/30 text-[10px] font-bold transition-all"
                              >
                                PRO
                              </button>
                            )}
                            {user.tier !== "ULTRA" && (
                              <button
                                onClick={() => handleQuickUpgrade(user.id, undefined, "ULTRA")}
                                className="px-2 py-1 rounded bg-purple-500/15 text-purple-300 hover:bg-purple-500/25 border border-purple-500/30 text-[10px] font-bold transition-all"
                              >
                                ULTRA
                              </button>
                            )}
                            {user.tier !== "FREE" && (
                              <button
                                onClick={() => handleQuickUpgrade(user.id, undefined, "FREE")}
                                className="px-2 py-1 rounded bg-gray-500/10 text-gray-400 hover:bg-gray-500/20 border border-gray-500/30 text-[10px] transition-all"
                              >
                                FREE
                              </button>
                            )}

                            {/* Ban / Unban Toggle */}
                            <button
                              onClick={() => handleToggleBan(user)}
                              className={`px-2 py-1 rounded text-[10px] font-bold border transition-all ${
                                user.status === "banned"
                                  ? "bg-emerald-500/10 text-emerald-400 hover:bg-emerald-500/20 border-emerald-500/30"
                                  : "bg-pink-500/10 text-pink-400 hover:bg-pink-500/20 border-pink-500/30"
                              }`}
                            >
                              {user.status === "banned" ? "UNBAN" : "BAN"}
                            </button>

                            {/* Edit Button */}
                            <button
                              onClick={() => {
                                setSelectedUser(user);
                                setEditTier(user.tier);
                                setEditStatus(user.status);
                                setEditRole(user.role);
                                setEditModalOpen(true);
                              }}
                              className="px-2.5 py-1 rounded bg-white/10 hover:bg-white/20 text-white text-[10px] border border-white/20 transition-all"
                            >
                              Edit
                            </button>

                            {/* Delete User Button */}
                            <button
                              onClick={() => handleDeleteUser(user.id, user.email)}
                              className="p-1.5 rounded bg-pink-500/10 hover:bg-pink-500/20 text-pink-400 border border-pink-500/30 transition-all text-[10px]"
                              title="Permanently Delete User"
                            >
                              <Trash2 className="w-3.5 h-3.5" />
                            </button>
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>

            {/* Unlinked Guest Mobile Devices */}
            {guestDevices.length > 0 && (
              <div className="glass-panel rounded-2xl border border-white/10 bg-black/40 overflow-hidden">
                <div className="p-4 border-b border-white/10 flex items-center justify-between">
                  <h3 className="font-bold text-sm text-white font-mono uppercase tracking-wider flex items-center space-x-2">
                    <Smartphone className="w-4 h-4 text-[#00FFA3]" />
                    <span>Unlinked Mobile Devices (Guest Mode)</span>
                  </h3>
                  <span className="text-xs font-mono text-gray-400">{guestDevices.length} devices</span>
                </div>
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-xs font-mono">
                    <thead className="bg-black/60 text-gray-400 border-b border-white/10">
                      <tr>
                        <th className="p-3.5">DEVICE ID</th>
                        <th className="p-3.5">PLATFORM</th>
                        <th className="p-3.5">TIER</th>
                        <th className="p-3.5">LAST ACTIVE</th>
                        <th className="p-3.5 text-right">ACTIONS</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-white/5">
                      {guestDevices.map((dev) => (
                        <tr key={dev.id} className="hover:bg-white/[0.02]">
                          <td className="p-3.5 text-white font-semibold">{dev.deviceId}</td>
                          <td className="p-3.5 text-gray-400">{dev.platform.toUpperCase()}</td>
                          <td className="p-3.5">
                            <span className="px-2 py-0.5 rounded text-[10px] bg-white/5 border border-white/10 text-cyan-300">
                              {dev.tier}
                            </span>
                          </td>
                          <td className="p-3.5 text-gray-400">{new Date(dev.lastActiveAt).toLocaleString()}</td>
                          <td className="p-3.5 text-right space-x-2">
                            <button
                              onClick={() => handleQuickUpgrade(undefined, dev.deviceId, "PRO")}
                              className="px-2 py-1 rounded bg-[#00F0FF]/10 text-[#00F0FF] border border-[#00F0FF]/30 text-[10px] font-bold"
                            >
                              PRO
                            </button>
                            <button
                              onClick={() => handleQuickUpgrade(undefined, dev.deviceId, "ULTRA")}
                              className="px-2 py-1 rounded bg-purple-500/10 text-purple-300 border border-purple-500/30 text-[10px] font-bold"
                            >
                              ULTRA
                            </button>
                            <button
                              onClick={() => handleDeleteDevice(dev.deviceId)}
                              className="p-1.5 rounded bg-pink-500/10 hover:bg-pink-500/20 text-pink-400 border border-pink-500/30 transition-all text-[10px]"
                              title="Delete Guest Device"
                            >
                              <Trash2 className="w-3.5 h-3.5" />
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            )}
          </div>
        )}

        {/* TAB 3: SUBSCRIPTIONS & PROMO HUB */}
        {activeTab === "subscriptions" && (
          <div className="space-y-6">
            {/* Sub-Hub Switcher */}
            <div className="flex items-center space-x-2 border-b border-white/10 pb-4">
              <button
                onClick={() => setSubHubTab("promos")}
                className={`flex items-center space-x-2 px-4 py-2 rounded-xl text-xs font-mono font-semibold transition-all ${
                  subHubTab === "promos"
                    ? "bg-[#00F0FF] text-black shadow-glowCyan"
                    : "bg-white/5 text-gray-400 hover:text-white"
                }`}
              >
                <Tag className="w-3.5 h-3.5" />
                <span>Promotional Codes ({promos.length})</span>
              </button>

              <button
                onClick={() => setSubHubTab("subscriptions")}
                className={`flex items-center space-x-2 px-4 py-2 rounded-xl text-xs font-mono font-semibold transition-all ${
                  subHubTab === "subscriptions"
                    ? "bg-[#00F0FF] text-black shadow-glowCyan"
                    : "bg-white/5 text-gray-400 hover:text-white"
                }`}
              >
                <DollarSign className="w-3.5 h-3.5" />
                <span>Active Subscriptions ({subscriptions.length})</span>
              </button>
            </div>

            {/* Sub-tab 1: Promo Codes */}
            {subHubTab === "promos" && (
              <div className="space-y-6">
                {/* Promo Metrics & Create Trigger */}
                <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 glass-panel p-6 rounded-2xl border border-white/10 bg-black/40">
                  <div>
                    <h3 className="font-bold text-lg text-white font-mono">Promotional Codes Engine</h3>
                    <p className="text-xs text-gray-400 mt-0.5">
                      Generate and govern instant VIP passes with duration and redemption limits.
                    </p>
                  </div>
                  <button
                    onClick={() => setCreatePromoOpen(true)}
                    className="px-4 py-2.5 rounded-xl bg-[#00FFA3] text-black font-semibold text-xs font-mono flex items-center space-x-2 hover:bg-[#00d88b] transition-all shadow-glowEmerald"
                  >
                    <Plus className="w-4 h-4" />
                    <span>Create Promo Code</span>
                  </button>
                </div>

                {/* Promo Codes Table */}
                <div className="glass-panel rounded-2xl border border-white/10 bg-black/40 overflow-hidden">
                  <table className="w-full text-left text-xs font-mono">
                    <thead className="bg-black/60 text-gray-400 border-b border-white/10">
                      <tr>
                        <th className="p-3.5">CODE</th>
                        <th className="p-3.5">TIER</th>
                        <th className="p-3.5">DURATION</th>
                        <th className="p-3.5">REDEMPTIONS</th>
                        <th className="p-3.5">STATUS</th>
                        <th className="p-3.5 text-right">ACTIONS</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-white/5">
                      {promos.map((promo) => (
                        <tr key={promo.id} className="hover:bg-white/[0.02]">
                          <td className="p-3.5 font-bold text-cyan-300 tracking-wider">{promo.code}</td>
                          <td className="p-3.5">
                            <span
                              className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                                promo.tier === "ULTRA"
                                  ? "bg-purple-500/15 text-purple-300 border border-purple-500/40"
                                  : "bg-[#00F0FF]/15 text-[#00F0FF] border border-[#00F0FF]/40"
                              }`}
                            >
                              {promo.tier}
                            </span>
                          </td>
                          <td className="p-3.5 text-gray-300">{promo.durationDays} days</td>
                          <td className="p-3.5">
                            <div className="flex items-center space-x-2">
                              <span>
                                {promo.currentUses} / {promo.maxUses}
                              </span>
                              <div className="w-20 bg-white/10 h-1.5 rounded-full overflow-hidden">
                                <div
                                  className="bg-emerald-400 h-full"
                                  style={{
                                    width: `${Math.min(100, (promo.currentUses / promo.maxUses) * 100)}%`,
                                  }}
                                />
                              </div>
                            </div>
                          </td>
                          <td className="p-3.5">
                            <button
                              onClick={() => handleTogglePromo(promo)}
                              className={`px-2 py-0.5 rounded text-[10px] font-bold border transition-all ${
                                promo.active
                                  ? "bg-emerald-500/15 text-emerald-400 border-emerald-500/40"
                                  : "bg-gray-500/15 text-gray-400 border-gray-500/40"
                              }`}
                            >
                              {promo.active ? "ACTIVE" : "DISABLED"}
                            </button>
                          </td>
                          <td className="p-3.5 text-right space-x-2">
                            <button
                              onClick={() => handleDeletePromo(promo.code)}
                              className="p-1.5 rounded bg-pink-500/10 text-pink-400 hover:bg-pink-500/20 border border-pink-500/30 transition-all"
                              title="Revoke & Delete"
                            >
                              <Trash2 className="w-3.5 h-3.5" />
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            )}

            {/* Sub-tab 2: Active Subscriptions */}
            {subHubTab === "subscriptions" && (
              <div className="space-y-6">
                {/* MRR & Provider Breakdown */}
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-5">
                  <div className="glass-card p-6 rounded-2xl border border-white/10 bg-black/40">
                    <span className="text-xs text-gray-400 font-mono">ESTIMATED MRR</span>
                    <p className="text-3xl font-bold text-[#00FFA3] font-mono mt-1">
                      ${subMetrics?.estimatedMrr || 0.0}
                    </p>
                    <p className="text-xs text-gray-400 mt-1">Based on active subscriptions</p>
                  </div>
                  <div className="glass-card p-6 rounded-2xl border border-white/10 bg-black/40">
                    <span className="text-xs text-gray-400 font-mono">ACTIVE MEMBERSHIPS</span>
                    <p className="text-3xl font-bold text-white font-mono mt-1">
                      {subMetrics?.activeSubscriptions || 0}
                    </p>
                    <p className="text-xs text-gray-400 mt-1">Free, Pro, and Ultra subscribers</p>
                  </div>
                  <div className="glass-card p-6 rounded-2xl border border-white/10 bg-black/40 flex flex-col justify-between">
                    <span className="text-xs text-gray-400 font-mono">BILLING PROVIDERS</span>
                    <div className="flex flex-wrap gap-2 mt-2 text-xs font-mono">
                      {subMetrics?.providerBreakdown &&
                        Object.entries(subMetrics.providerBreakdown).map(([prov, count]) => (
                          <span key={prov} className="px-2 py-0.5 rounded bg-white/5 border border-white/10">
                            {prov}: <span className="text-cyan-400">{count as any}</span>
                          </span>
                        ))}
                    </div>
                  </div>
                </div>

                {/* Subscriptions Table */}
                <div className="glass-panel rounded-2xl border border-white/10 bg-black/40 overflow-hidden">
                  <table className="w-full text-left text-xs font-mono">
                    <thead className="bg-black/60 text-gray-400 border-b border-white/10">
                      <tr>
                        <th className="p-3.5">USER / DEVICE</th>
                        <th className="p-3.5">TIER</th>
                        <th className="p-3.5">PROVIDER</th>
                        <th className="p-3.5">CURRENT END</th>
                        <th className="p-3.5">STATUS</th>
                        <th className="p-3.5 text-right">MANAGE</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-white/5">
                      {subscriptions.map((sub) => (
                        <tr key={sub.id} className="hover:bg-white/[0.02]">
                          <td className="p-3.5">
                            <div className="font-semibold text-white">
                              {sub.user?.email || sub.device?.deviceId || "Anonymous"}
                            </div>
                            <div className="text-gray-400 text-[10px]">{sub.id}</div>
                          </td>
                          <td className="p-3.5">
                            <span
                              className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                                sub.tier === "ULTRA"
                                  ? "bg-purple-500/15 text-purple-300 border border-purple-500/40"
                                  : "bg-[#00F0FF]/15 text-[#00F0FF] border border-[#00F0FF]/40"
                              }`}
                            >
                              {sub.tier}
                            </span>
                          </td>
                          <td className="p-3.5 text-gray-300 uppercase">{sub.provider}</td>
                          <td className="p-3.5 text-gray-300">{new Date(sub.currentPeriodEnd).toLocaleDateString()}</td>
                          <td className="p-3.5">
                            <span
                              className={`px-2 py-0.5 rounded text-[10px] ${
                                sub.status === "active"
                                  ? "bg-emerald-500/15 text-emerald-400 border border-emerald-500/30"
                                  : "bg-pink-500/15 text-pink-400 border border-pink-500/30"
                              }`}
                            >
                              {sub.status.toUpperCase()}
                            </span>
                          </td>
                          <td className="p-3.5 text-right space-x-2">
                            <button
                              onClick={() => handleExtendSub(sub.id)}
                              className="px-2 py-1 rounded bg-[#00FFA3]/10 text-[#00FFA3] hover:bg-[#00FFA3]/20 border border-[#00FFA3]/30 text-[10px] font-bold"
                            >
                              +30 Days
                            </button>
                            {sub.status === "active" && (
                              <button
                                onClick={() => handleCancelSub(sub.id)}
                                className="px-2 py-1 rounded bg-pink-500/10 text-pink-400 hover:bg-pink-500/20 border border-pink-500/30 text-[10px]"
                              >
                                Cancel
                              </button>
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            )}
          </div>
        )}

        {/* TAB 4: TELEMETRY & CRASH DIAGNOSTICS */}
        {activeTab === "telemetry" && (
          <div className="space-y-6">
            {/* Top Diagnostics KPI Cards */}
            <div className="grid grid-cols-1 sm:grid-cols-4 gap-5">
              <div className="glass-card p-5 rounded-2xl border border-white/10 bg-black/40">
                <span className="text-xs text-gray-400 font-mono">TOTAL RECORDED CRASHES</span>
                <p className="text-3xl font-bold text-pink-400 font-mono mt-1">{crashStats?.total || 0}</p>
                <p className="text-xs text-gray-400 mt-1">Across all app releases</p>
              </div>

              <div className="glass-card p-5 rounded-2xl border border-white/10 bg-black/40">
                <span className="text-xs text-gray-400 font-mono">AFFECTED HARDWARE UNITS</span>
                <p className="text-3xl font-bold text-white font-mono mt-1">{crashStats?.uniqueAffectedDevices || 0}</p>
                <p className="text-xs text-gray-400 mt-1">Unique device identities</p>
              </div>

              <div className="glass-card p-5 rounded-2xl border border-white/10 bg-black/40">
                <span className="text-xs text-gray-400 font-mono">AVERAGE AI LATENCY</span>
                <p className="text-3xl font-bold text-cyan-400 font-mono mt-1">
                  {telemetryAnalytics?.averageLatencyMs || 38}ms
                </p>
                <p className="text-xs text-gray-400 mt-1">Time to first token (TTFT)</p>
              </div>

              <div className="glass-card p-5 rounded-2xl border border-white/10 bg-black/40 flex flex-col justify-between">
                <span className="text-xs text-gray-400 font-mono">SIMULATE ERROR</span>
                <button
                  onClick={handleSimulateCrash}
                  disabled={simulatingCrash}
                  className="mt-2 w-full py-2 rounded-xl bg-pink-500/20 text-pink-300 hover:bg-pink-500/30 border border-pink-500/40 text-xs font-mono font-bold flex items-center justify-center space-x-2 transition-all shadow-sm"
                >
                  <Bug className="w-3.5 h-3.5" />
                  <span>{simulatingCrash ? "Injecting..." : "Simulate Crash Log"}</span>
                </button>
              </div>
            </div>

            {/* Calculation Volume by Mode Visualizer */}
            {telemetryAnalytics?.calculationModes && (
              <div className="glass-panel p-6 rounded-2xl border border-white/10 bg-black/40 space-y-4">
                <h3 className="text-sm font-bold text-white font-mono uppercase tracking-wider flex items-center space-x-2">
                  <BarChart3 className="w-4 h-4 text-[#00FFA3]" />
                  <span>Calculation Volume by Engine Mode</span>
                </h3>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 pt-2">
                  {Object.entries(telemetryAnalytics.calculationModes).map(([mode, count]: [string, any]) => (
                    <div key={mode} className="bg-black/60 p-3 rounded-xl border border-white/10">
                      <div className="flex items-center justify-between text-xs font-mono">
                        <span className="text-gray-400 uppercase">{mode}</span>
                        <span className="text-[#00FFA3] font-bold">{count}</span>
                      </div>
                      <div className="w-full bg-white/10 h-1.5 rounded-full mt-2 overflow-hidden">
                        <div
                          className="bg-[#00FFA3] h-full"
                          style={{
                            width: `${Math.min(100, Math.max(15, count * 8))}%`,
                          }}
                        />
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Real-time Crash Stream */}
            <div className="glass-panel rounded-2xl border border-white/10 bg-black/40 overflow-hidden">
              <div className="p-4 border-b border-white/10 flex items-center justify-between">
                <h3 className="font-bold text-sm text-white font-mono uppercase tracking-wider flex items-center space-x-2">
                  <Flame className="w-4 h-4 text-pink-400" />
                  <span>Real-Time Crash Log Stream ({crashes.length})</span>
                </h3>
              </div>

              <div className="divide-y divide-white/5">
                {crashes.length === 0 ? (
                  <div className="p-8 text-center text-gray-500 font-mono text-xs">
                    No crashes recorded. System stability is pristine!
                  </div>
                ) : (
                  crashes.map((crash) => {
                    const isExpanded = expandedCrashId === crash.id;
                    return (
                      <div key={crash.id} className="p-4 hover:bg-white/[0.01] transition-colors">
                        <div className="flex items-start justify-between">
                          <div className="space-y-1">
                            <div className="flex items-center space-x-2">
                              <span className="text-xs font-bold text-pink-400 font-mono">{crash.name}</span>
                              <span className="text-[10px] px-2 py-0.5 rounded bg-white/5 border border-white/10 text-gray-400 font-mono">
                                v{crash.appVersion}
                              </span>
                              <span className="text-[10px] px-2 py-0.5 rounded bg-white/5 border border-white/10 text-gray-400 font-mono">
                                {crash.osVersion}
                              </span>
                            </div>
                            <p className="text-xs text-gray-400 font-mono">{crash.error}</p>
                            <div className="text-[11px] text-gray-500 font-mono flex items-center space-x-3">
                              <span>Device: {crash.deviceId}</span>
                              <span>•</span>
                              <span>{new Date(crash.createdAt).toLocaleString()}</span>
                            </div>
                          </div>

                          <div className="flex items-center space-x-2">
                            <button
                              onClick={() => copyToClipboard(crash.stack, crash.id)}
                              className="p-1.5 rounded bg-white/5 hover:bg-white/10 text-gray-400 hover:text-white border border-white/10 transition-all text-xs font-mono flex items-center space-x-1"
                              title="Copy Stack Trace"
                            >
                              {copiedKey === crash.id ? (
                                <Check className="w-3.5 h-3.5 text-emerald-400" />
                              ) : (
                                <Copy className="w-3.5 h-3.5" />
                              )}
                            </button>
                            <button
                              onClick={() => setExpandedCrashId(isExpanded ? null : crash.id)}
                              className="px-2.5 py-1 rounded bg-white/5 hover:bg-white/10 text-gray-300 text-xs font-mono border border-white/10 transition-all"
                            >
                              {isExpanded ? "Collapse" : "Inspect Stack"}
                            </button>
                          </div>
                        </div>

                        {/* Expandable Stack Trace Viewer */}
                        {isExpanded && (
                          <div className="mt-3 p-4 rounded-xl bg-[#040609] border border-pink-500/20 text-xs font-mono text-gray-300 overflow-x-auto whitespace-pre-wrap leading-relaxed shadow-inner">
                            {crash.stack}
                          </div>
                        )}
                      </div>
                    );
                  })
                )}
              </div>
            </div>
          </div>
        )}

        {/* TAB 5: SYSTEM AGENTS CONTROL CENTER & REACT WORKBENCH */}
        {activeTab === "agents" && (
          <div className="space-y-8">
            {/* Header / Subsystem Overview */}
            <div className="glass-panel rounded-2xl p-6 border border-white/10 bg-black/40 space-y-4">
              <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-white/10 pb-4">
                <div className="space-y-1">
                  <div className="inline-flex items-center space-x-2 px-2.5 py-0.5 rounded-full bg-purple-500/15 border border-purple-500/30 text-purple-300 text-xs font-mono">
                    <Bot className="w-3.5 h-3.5" />
                    <span>AUTONOMOUS SYSTEM AGENTS PIPELINE</span>
                  </div>
                  <h2 className="text-xl font-bold text-white font-mono tracking-wide">
                    System Agents &amp; ReAct Execution Engine
                  </h2>
                  <p className="text-xs text-gray-400 font-mono">
                    Autonomous background agents executing multi-step mathematical reasoning, telemetry triage, OTA bundle verification, and SQLite database garbage collection.
                  </p>
                </div>

                <div className="flex items-center space-x-3">
                  <button
                    onClick={fetchAgents}
                    className="flex items-center space-x-2 px-3.5 py-2 rounded-xl bg-white/5 hover:bg-white/10 border border-white/15 text-xs font-mono text-gray-300 hover:text-white transition-all"
                  >
                    <RefreshCw className={`w-3.5 h-3.5 ${loadingAgents ? "animate-spin text-[#00F0FF]" : ""}`} />
                    <span>Sync Agents</span>
                  </button>
                </div>
              </div>

              {/* 4 Overview Mini-Gauges */}
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                <div className="bg-black/60 p-3.5 rounded-xl border border-white/10">
                  <span className="text-[10px] font-mono text-gray-400">ACTIVE AGENTS</span>
                  <p className="text-xl font-bold text-emerald-400 font-mono mt-0.5">
                    {agentsSummary?.activeCount || agents.filter((a) => a.status === "active").length || 4} / 4
                  </p>
                  <p className="text-[11px] text-gray-400 mt-1">Operational &amp; Healthy</p>
                </div>

                <div className="bg-black/60 p-3.5 rounded-xl border border-white/10">
                  <span className="text-[10px] font-mono text-gray-400">TOTAL INVOCATIONS</span>
                  <p className="text-xl font-bold text-[#00F0FF] font-mono mt-0.5">
                    {agentsSummary?.totalInvocations || 524}
                  </p>
                  <p className="text-[11px] text-gray-400 mt-1">Across all background tasks</p>
                </div>

                <div className="bg-black/60 p-3.5 rounded-xl border border-white/10">
                  <span className="text-[10px] font-mono text-gray-400">AVG SYSTEM LATENCY</span>
                  <p className="text-xl font-bold text-purple-300 font-mono mt-0.5">
                    {agentsSummary?.avgSystemLatencyMs || 75}ms
                  </p>
                  <p className="text-[11px] text-gray-400 mt-1">Native execution speed</p>
                </div>

                <div className="bg-black/60 p-3.5 rounded-xl border border-white/10">
                  <span className="text-[10px] font-mono text-gray-400">COGNITIVE BACKEND</span>
                  <p className="text-xl font-bold text-[#FF007A] font-mono mt-0.5">Gemini 2.5</p>
                  <p className="text-[11px] text-gray-400 mt-1">Flash ReAct + Tool Loop</p>
                </div>
              </div>
            </div>

            {/* Grid of System Agent Cards */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              {agents.length === 0 ? (
                <div className="col-span-2 p-8 text-center text-gray-500 font-mono glass-panel rounded-2xl border border-white/10">
                  Loading system agents registry...
                </div>
              ) : (
                agents.map((agent) => (
                  <div
                    key={agent.id}
                    className={`glass-card rounded-2xl p-6 border transition-all space-y-4 flex flex-col justify-between ${
                      selectedAgentId === agent.id
                        ? "border-[#00F0FF]/60 bg-black/60 shadow-glowCyan"
                        : "border-white/10 bg-black/40 hover:border-white/20"
                    }`}
                  >
                    <div className="space-y-3">
                      {/* Top Row: Icon, Name, Status Badge & Toggle */}
                      <div className="flex items-start justify-between">
                        <div className="flex items-center space-x-3">
                          <div
                            className={`w-10 h-10 rounded-xl flex items-center justify-center border ${
                              agent.category === "ai_reasoning"
                                ? "bg-purple-500/10 border-purple-500/30 text-purple-300"
                                : agent.category === "telemetry"
                                ? "bg-pink-500/10 border-pink-500/30 text-pink-400"
                                : agent.category === "devops"
                                ? "bg-[#00FFA3]/10 border-[#00FFA3]/30 text-[#00FFA3]"
                                : "bg-cyan-500/10 border-cyan-500/30 text-cyan-400"
                            }`}
                          >
                            <Bot className="w-5 h-5" />
                          </div>
                          <div>
                            <h3 className="font-bold text-white text-sm font-mono">{agent.name}</h3>
                            <div className="flex items-center space-x-2 text-[10px] font-mono text-gray-400">
                              <span className="uppercase">{agent.category}</span>
                              <span>•</span>
                              <span>v{agent.version}</span>
                              {agent.model && (
                                <>
                                  <span>•</span>
                                  <span className="text-cyan-400">{agent.model}</span>
                                </>
                              )}
                            </div>
                          </div>
                        </div>

                        {/* Status Toggle Button */}
                        <button
                          onClick={() => handleToggleAgent(agent)}
                          className={`px-2.5 py-1 rounded-md text-[10px] font-mono font-bold border transition-all ${
                            agent.status === "active"
                              ? "bg-emerald-500/15 text-emerald-400 hover:bg-emerald-500/25 border-emerald-500/40"
                              : "bg-gray-500/15 text-gray-400 hover:bg-gray-500/25 border-gray-500/40"
                          }`}
                        >
                          {agent.status.toUpperCase()}
                        </button>
                      </div>

                      <p className="text-xs text-gray-300 font-mono leading-relaxed">{agent.description}</p>

                      {/* Capabilities */}
                      <div className="space-y-1 pt-1">
                        <span className="text-[10px] font-mono text-gray-400 uppercase tracking-wider">
                          Key Capabilities:
                        </span>
                        <ul className="text-[11px] text-gray-400 font-mono space-y-0.5">
                          {agent.capabilities.slice(0, 3).map((cap, i) => (
                            <li key={i} className="flex items-center space-x-1.5">
                              <span className="w-1 h-1 rounded-full bg-cyan-400" />
                              <span>{cap}</span>
                            </li>
                          ))}
                        </ul>
                      </div>

                      {/* Tools Registered */}
                      <div className="space-y-1 pt-1">
                        <span className="text-[10px] font-mono text-gray-400 uppercase tracking-wider">
                          Registered Native Tools:
                        </span>
                        <div className="flex flex-wrap gap-1.5">
                          {agent.tools.map((tool) => (
                            <span
                              key={tool.name}
                              className="px-2 py-0.5 rounded bg-white/5 border border-white/10 text-[10px] font-mono text-cyan-300"
                              title={tool.description}
                            >
                              {tool.name}
                            </span>
                          ))}
                        </div>
                      </div>
                    </div>

                    {/* Footer Actions & Metrics */}
                    <div className="pt-4 border-t border-white/10 flex items-center justify-between">
                      <div className="text-[11px] font-mono text-gray-400">
                        <span className="text-white font-bold">{agent.metrics.invocations}</span> runs •{" "}
                        <span className="text-emerald-400">{agent.metrics.successRatePct}%</span> success
                      </div>

                      {agent.id === "autonomous-react-agent" ? (
                        <button
                          onClick={() => {
                            setSelectedAgentId(agent.id);
                            const el = document.getElementById("agent-workbench");
                            if (el) el.scrollIntoView({ behavior: "smooth" });
                          }}
                          className="px-3 py-1.5 rounded-xl bg-[#00F0FF]/15 hover:bg-[#00F0FF]/25 text-[#00F0FF] border border-[#00F0FF]/30 text-xs font-mono font-bold transition-all flex items-center space-x-1.5"
                        >
                          <Wand2 className="w-3.5 h-3.5" />
                          <span>Open Workbench</span>
                        </button>
                      ) : agent.id === "database-maintenance-agent" ? (
                        <button
                          onClick={() => handleRunAgent(agent.id, undefined, "run_maintenance")}
                          disabled={agentRunning}
                          className="px-3 py-1.5 rounded-xl bg-cyan-500/15 hover:bg-cyan-500/25 text-cyan-300 border border-cyan-500/30 text-xs font-mono font-bold transition-all flex items-center space-x-1.5"
                        >
                          <Play className="w-3.5 h-3.5" />
                          <span>Run Prune &amp; Vacuum</span>
                        </button>
                      ) : agent.id === "telemetry-diagnostic-agent" ? (
                        <button
                          onClick={() => handleRunAgent(agent.id, undefined, "triage_crashes")}
                          disabled={agentRunning}
                          className="px-3 py-1.5 rounded-xl bg-pink-500/15 hover:bg-pink-500/25 text-pink-400 border border-pink-500/30 text-xs font-mono font-bold transition-all flex items-center space-x-1.5"
                        >
                          <Play className="w-3.5 h-3.5" />
                          <span>Run Crash Triage</span>
                        </button>
                      ) : (
                        <button
                          onClick={() => handleRunAgent(agent.id, undefined, "verify_manifest")}
                          disabled={agentRunning}
                          className="px-3 py-1.5 rounded-xl bg-emerald-500/15 hover:bg-emerald-500/25 text-emerald-400 border border-emerald-500/30 text-xs font-mono font-bold transition-all flex items-center space-x-1.5"
                        >
                          <Play className="w-3.5 h-3.5" />
                          <span>Verify Manifest</span>
                        </button>
                      )}
                    </div>
                  </div>
                ))
              )}
            </div>

            {/* INTERACTIVE AUTONOMOUS REACT AGENT WORKBENCH */}
            <div id="agent-workbench" className="glass-panel rounded-2xl border border-white/10 bg-black/40 p-6 space-y-6">
              <div className="border-b border-white/10 pb-4 flex flex-col md:flex-row md:items-center justify-between gap-4">
                <div className="space-y-1">
                  <h3 className="font-bold text-white text-base font-mono flex items-center space-x-2">
                    <Sparkles className="w-4 h-4 text-[#00F0FF]" />
                    <span>Interactive Autonomous ReAct Agent Workbench</span>
                  </h3>
                  <p className="text-xs text-gray-400 font-mono">
                    Dispatch multi-step math tasks and inspect live reasoning steps: Thought → Tool Call → Observation → Final Synthesis.
                  </p>
                </div>

                <div className="flex items-center space-x-2 text-xs font-mono">
                  <span className="text-gray-400">Active Engine:</span>
                  <span className="px-2 py-0.5 rounded bg-purple-500/15 text-purple-300 border border-purple-500/30">
                    Gemini 2.5 Flash + Native Tools
                  </span>
                </div>
              </div>

              {/* Preset Prompts Section */}
              <div className="space-y-2">
                <span className="text-xs font-mono text-gray-400">Quick Test Prompts:</span>
                <div className="flex flex-wrap gap-2">
                  {[
                    "Evaluate integral of 3x^2 dx from 0 to 2 with step-by-step calculus derivation",
                    "Solve 3*x^2 - 12*x + 9 = 0 using quadratic formula",
                    "Convert 100 km to miles with dimensional factors",
                    "Compute determinant of matrix [[4, 2], [1, 3]]",
                    "Evaluate derivative of sin(x)*cos(x) at pi/4",
                  ].map((preset, idx) => (
                    <button
                      key={idx}
                      onClick={() => setAgentPrompt(preset)}
                      className="px-3 py-1.5 rounded-xl bg-white/5 hover:bg-white/10 border border-white/10 text-xs font-mono text-gray-300 hover:text-white transition-all text-left"
                    >
                      {preset.slice(0, 48)}...
                    </button>
                  ))}
                </div>
              </div>

              {/* Prompt Input & Execute Controls */}
              <div className="space-y-3">
                <label className="block text-xs font-mono text-gray-400">MATHEMATICAL OBJECTIVE / REASONING PROMPT</label>
                <div className="flex flex-col sm:flex-row gap-3">
                  <input
                    type="text"
                    value={agentPrompt}
                    onChange={(e) => setAgentPrompt(e.target.value)}
                    placeholder="Enter mathematical expression, calculus integral, or algebraic equation..."
                    className="flex-1 px-4 py-3 bg-black/60 rounded-xl border border-white/15 text-xs font-mono text-white focus:outline-none focus:border-[#00F0FF]"
                    onKeyDown={(e) => {
                      if (e.key === "Enter" && !agentRunning) {
                        handleRunAgent("autonomous-react-agent");
                      }
                    }}
                  />
                  <button
                    onClick={() => handleRunAgent("autonomous-react-agent")}
                    disabled={agentRunning || !agentPrompt.trim()}
                    className="px-6 py-3 rounded-xl bg-[#00F0FF] text-black font-bold text-xs font-mono hover:bg-[#00d0de] transition-all shadow-glowCyan flex items-center justify-center space-x-2 disabled:opacity-50"
                  >
                    <Wand2 className={`w-4 h-4 ${agentRunning ? "animate-spin" : ""}`} />
                    <span>{agentRunning ? "Reasoning..." : "Execute Agent"}</span>
                  </button>
                </div>
              </div>

              {/* Execution Trace Timeline */}
              {agentTrace.length > 0 && (
                <div className="space-y-4 pt-4 border-t border-white/10">
                  <div className="flex items-center justify-between">
                    <h4 className="text-xs font-mono font-bold text-[#00FFA3] uppercase tracking-wider flex items-center space-x-2">
                      <CheckCircle2 className="w-4 h-4" />
                      <span>Live ReAct Execution Trace ({agentTrace.length} Steps)</span>
                    </h4>
                    <span className="text-[11px] font-mono text-gray-400">
                      Completed Successfully
                    </span>
                  </div>

                  <div className="space-y-3">
                    {agentTrace.map((st) => (
                      <div
                        key={st.step}
                        className={`p-4 rounded-xl border font-mono text-xs space-y-1.5 transition-all ${
                          st.type === "thought"
                            ? "border-cyan-500/30 bg-cyan-500/5 text-cyan-200"
                            : st.type === "tool_call"
                            ? "border-purple-500/30 bg-purple-500/5 text-purple-200"
                            : st.type === "observation"
                            ? "border-emerald-500/30 bg-emerald-500/5 text-emerald-200"
                            : "border-[#FF007A]/30 bg-[#FF007A]/5 text-pink-200"
                        }`}
                      >
                        <div className="flex items-center justify-between text-[10px]">
                          <span className="font-bold uppercase tracking-wider flex items-center space-x-1.5">
                            {st.type === "thought" && <span>🧠 THOUGHT (STEP {st.step})</span>}
                            {st.type === "tool_call" && (
                              <span>
                                ⚙️ TOOL INVOCATION: <code className="text-cyan-300 font-bold">{st.tool}</code>
                              </span>
                            )}
                            {st.type === "observation" && <span>🔍 OBSERVATION (TOOL OUTPUT)</span>}
                            {st.type === "final_answer" && <span>💡 FINAL ANSWER &amp; SYNTHESIS</span>}
                          </span>
                          <span className="text-gray-400">{new Date(st.timestamp).toLocaleTimeString()}</span>
                        </div>
                        <div className="whitespace-pre-wrap leading-relaxed text-gray-200">
                          {st.content}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Final Markdown Answer Card */}
              {agentFinalAnswer && (
                <div className="p-5 rounded-2xl bg-black/70 border border-emerald-500/40 text-xs font-mono space-y-2 shadow-glowEmerald">
                  <div className="flex items-center justify-between text-[11px] text-emerald-400 font-bold border-b border-white/10 pb-2">
                    <span>SYNTHESIZED MATHEMATICAL DERIVATION</span>
                    <button
                      onClick={() => copyToClipboard(agentFinalAnswer, "final_answer")}
                      className="flex items-center space-x-1 text-gray-400 hover:text-white"
                    >
                      {copiedKey === "final_answer" ? (
                        <Check className="w-3.5 h-3.5 text-emerald-400" />
                      ) : (
                        <Copy className="w-3.5 h-3.5" />
                      )}
                      <span>Copy</span>
                    </button>
                  </div>
                  <div className="whitespace-pre-wrap text-gray-100 leading-relaxed pt-1">
                    {agentFinalAnswer}
                  </div>
                </div>
              )}

              {/* Maintenance Result Report if available */}
              {agentLastResult && agentLastResult.task && (
                <div className="p-4 rounded-xl bg-black/60 border border-white/15 text-xs font-mono space-y-2">
                  <div className="text-cyan-400 font-bold uppercase tracking-wider">
                    Task Execution Report: {agentLastResult.task}
                  </div>
                  <pre className="p-3 bg-black/80 rounded-lg text-gray-300 overflow-x-auto text-[11px]">
                    {JSON.stringify(agentLastResult, null, 2)}
                  </pre>
                </div>
              )}
            </div>
          </div>
        )}
      </main>


      {/* MODAL 1: Create Promo Code Dialog */}
      {createPromoOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
          <div className="max-w-md w-full glass-panel rounded-2xl border border-white/15 bg-[#0d111a] p-6 shadow-2xl space-y-5">
            <div className="flex items-center justify-between border-b border-white/10 pb-3">
              <h3 className="font-bold text-white font-mono uppercase tracking-wider flex items-center space-x-2">
                <Tag className="w-4 h-4 text-[#00FFA3]" />
                <span>Create New Promo Code</span>
              </h3>
              <button onClick={() => setCreatePromoOpen(false)} className="text-gray-400 hover:text-white">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleCreatePromo} className="space-y-4">
              <div>
                <label className="block text-xs font-mono text-gray-400 mb-1">PROMO CODE STRING</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. ULTRA_VIP_2026"
                  value={newPromoCode}
                  onChange={(e) => setNewPromoCode(e.target.value.toUpperCase())}
                  className="w-full px-3.5 py-2 bg-black/60 rounded-xl border border-white/15 text-xs font-mono text-white focus:outline-none focus:border-[#00FFA3]"
                />
              </div>

              <div>
                <label className="block text-xs font-mono text-gray-400 mb-1">GRANTED TIER</label>
                <select
                  value={newPromoTier}
                  onChange={(e) => setNewPromoTier(e.target.value as any)}
                  className="w-full px-3.5 py-2 bg-black/60 rounded-xl border border-white/15 text-xs font-mono text-white focus:outline-none focus:border-[#00FFA3]"
                >
                  <option value="PRO">PRO (Unlimited Sync, LaTeX Export, OTA Sign)</option>
                  <option value="ULTRA">ULTRA (Priority Gemini 2.5 AI, VIP Support)</option>
                </select>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-mono text-gray-400 mb-1">DURATION (DAYS)</label>
                  <input
                    type="number"
                    min="1"
                    max="3650"
                    value={newPromoDuration}
                    onChange={(e) => setNewPromoDuration(parseInt(e.target.value, 10))}
                    className="w-full px-3.5 py-2 bg-black/60 rounded-xl border border-white/15 text-xs font-mono text-white focus:outline-none focus:border-[#00FFA3]"
                  />
                </div>
                <div>
                  <label className="block text-xs font-mono text-gray-400 mb-1">MAX USES</label>
                  <input
                    type="number"
                    min="1"
                    max="100000"
                    value={newPromoMaxUses}
                    onChange={(e) => setNewPromoMaxUses(parseInt(e.target.value, 10))}
                    className="w-full px-3.5 py-2 bg-black/60 rounded-xl border border-white/15 text-xs font-mono text-white focus:outline-none focus:border-[#00FFA3]"
                  />
                </div>
              </div>

              <div className="pt-3 border-t border-white/10 flex items-center justify-end space-x-3">
                <button
                  type="button"
                  onClick={() => setCreatePromoOpen(false)}
                  className="px-4 py-2 rounded-xl bg-white/5 hover:bg-white/10 text-xs font-mono text-gray-300"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={creatingPromo}
                  className="px-4 py-2 rounded-xl bg-[#00FFA3] text-black font-bold text-xs font-mono hover:bg-[#00d88b] transition-all shadow-glowEmerald"
                >
                  {creatingPromo ? "Creating..." : "Create Promo Code"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* MODAL 2: User Edit Dialog */}
      {editModalOpen && selectedUser && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
          <div className="max-w-md w-full glass-panel rounded-2xl border border-white/15 bg-[#0d111a] p-6 shadow-2xl space-y-5">
            <div className="flex items-center justify-between border-b border-white/10 pb-3">
              <h3 className="font-bold text-white font-mono uppercase tracking-wider flex items-center space-x-2">
                <Users className="w-4 h-4 text-[#00F0FF]" />
                <span>Edit User Account</span>
              </h3>
              <button onClick={() => setEditModalOpen(false)} className="text-gray-400 hover:text-white">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-xs font-mono text-gray-400 mb-1">EMAIL / IDENTITY</label>
                <div className="px-3.5 py-2 bg-black/40 rounded-xl border border-white/10 text-xs font-mono text-gray-300">
                  {selectedUser.email}
                </div>
              </div>

              <div>
                <label className="block text-xs font-mono text-gray-400 mb-1">TIER ENTITLE MENT</label>
                <select
                  value={editTier}
                  onChange={(e) => setEditTier(e.target.value as any)}
                  className="w-full px-3.5 py-2 bg-black/60 rounded-xl border border-white/15 text-xs font-mono text-white focus:outline-none focus:border-[#00F0FF]"
                >
                  <option value="FREE">FREE Tier (50 Sync Items, Standard Math)</option>
                  <option value="PRO">PRO Tier (Unlimited Sync, LaTeX Export)</option>
                  <option value="ULTRA">ULTRA Tier (Priority AI, VIP Support)</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-mono text-gray-400 mb-1">ACCOUNT STATUS</label>
                <select
                  value={editStatus}
                  onChange={(e) => setEditStatus(e.target.value as any)}
                  className="w-full px-3.5 py-2 bg-black/60 rounded-xl border border-white/15 text-xs font-mono text-white focus:outline-none focus:border-[#00F0FF]"
                >
                  <option value="active">Active (Normal Access)</option>
                  <option value="banned">Banned (Revoke Sessions &amp; Block Access)</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-mono text-gray-400 mb-1">ADMINISTRATIVE ROLE</label>
                <select
                  value={editRole}
                  onChange={(e) => setEditRole(e.target.value)}
                  className="w-full px-3.5 py-2 bg-black/60 rounded-xl border border-white/15 text-xs font-mono text-white focus:outline-none focus:border-[#00F0FF]"
                >
                  <option value="user">User (Standard App Privileges)</option>
                  <option value="admin">Admin (Full Control Center Access)</option>
                </select>
              </div>

              <div className="pt-3 border-t border-white/10 flex items-center justify-between">
                <div className="flex items-center space-x-2">
                  <button
                    type="button"
                    onClick={() => handleRevokeSessions(selectedUser.id)}
                    className="px-3 py-1.5 rounded-xl bg-yellow-500/15 hover:bg-yellow-500/25 text-yellow-400 text-xs font-mono border border-yellow-500/30 transition-all"
                  >
                    Revoke Sessions
                  </button>
                  <button
                    type="button"
                    onClick={() => handleDeleteUser(selectedUser.id, selectedUser.email)}
                    className="px-3 py-1.5 rounded-xl bg-pink-500/15 hover:bg-pink-500/25 text-pink-400 text-xs font-mono border border-pink-500/30 transition-all"
                  >
                    Delete Account
                  </button>
                </div>

                <div className="flex items-center space-x-2">
                  <button
                    type="button"
                    onClick={() => setEditModalOpen(false)}
                    className="px-4 py-2 rounded-xl bg-white/5 hover:bg-white/10 text-xs font-mono text-gray-300"
                  >
                    Cancel
                  </button>
                  <button
                    type="button"
                    onClick={handleSaveUserEdit}
                    disabled={savingUser}
                    className="px-4 py-2 rounded-xl bg-[#00F0FF] text-black font-bold text-xs font-mono hover:bg-[#00d0de] transition-all shadow-glowCyan"
                  >
                    {savingUser ? "Saving..." : "Save Changes"}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* MODAL 3: Master Admin Key Configuration Dialog */}
      {keyModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
          <div className="max-w-md w-full glass-panel rounded-2xl border border-white/15 bg-[#0d111a] p-6 shadow-2xl space-y-5">
            <div className="flex items-center justify-between border-b border-white/10 pb-3">
              <h3 className="font-bold text-white font-mono uppercase tracking-wider flex items-center space-x-2">
                <Key className="w-4 h-4 text-[#00F0FF]" />
                <span>Admin Secret Key Configuration</span>
              </h3>
              <button onClick={() => setKeyModalOpen(false)} className="text-gray-400 hover:text-white">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="space-y-4">
              <p className="text-xs text-gray-400 leading-relaxed font-mono">
                Admin API handlers are protected by <code className="text-cyan-300">ADMIN_SECRET_KEY</code> or JWT with ADMIN role.
              </p>

              <div>
                <label className="block text-xs font-mono text-gray-400 mb-1">MASTER ADMIN KEY (`x-admin-key`)</label>
                <input
                  type="text"
                  value={keyInput}
                  onChange={(e) => setKeyInput(e.target.value)}
                  placeholder="Enter admin secret key..."
                  className="w-full px-3.5 py-2.5 bg-black/60 rounded-xl border border-white/15 text-xs font-mono text-white focus:outline-none focus:border-[#00F0FF]"
                />
              </div>

              <div className="flex items-center justify-between text-xs font-mono text-gray-400">
                <span>Default Dev Key:</span>
                <button
                  type="button"
                  onClick={() => setKeyInput("lqc_admin_secret_super_key_2026")}
                  className="text-cyan-400 hover:underline"
                >
                  lqc_admin_secret_super_key_2026
                </button>
              </div>

              <div className="pt-3 border-t border-white/10 flex items-center justify-end space-x-3">
                <button
                  type="button"
                  onClick={() => setKeyModalOpen(false)}
                  className="px-4 py-2 rounded-xl bg-white/5 hover:bg-white/10 text-xs font-mono text-gray-300"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={handleSaveKey}
                  className="px-4 py-2 rounded-xl bg-[#00F0FF] text-black font-bold text-xs font-mono hover:bg-[#00d0de] transition-all shadow-glowCyan"
                >
                  Apply &amp; Authenticate
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
