//
//  CloudSyncSheetView.swift
//  LiquidCalc
//
//  Compact Cloud Sync Quick Sheet
//  Displays sync quota, items count, network status, and account link / upgrade actions.
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

public struct CloudSyncSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var authManager = AuthManager.shared
    @Bindable private var subscriptionManager = SubscriptionManager.shared
    @Bindable private var syncManager = DeviceSyncManager.shared

    @State private var showAccountSettings: Bool = false
    @State private var showPaywall: Bool = false
    @State private var isSyncing: Bool = false
    @State private var syncNotice: String? = nil

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.11)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    // Header Status
                    HStack(spacing: 12) {
                        Image(systemName: subscriptionManager.isPaid ? "cloud.sun.fill" : "icloud.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: subscriptionManager.isPaid ? [.purple, .cyan] : [.cyan, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(subscriptionManager.cloudSyncStatusPillText)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text(authManager.isGuest ? "Guest Device • No Login Forced" : (authManager.currentUser?.email ?? "Account Synced"))
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }

                        Spacer()

                        Button(action: handleSync) {
                            if isSyncing {
                                ProgressView().tint(.cyan)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.cyan)
                                    .padding(8)
                                    .background(Color.cyan.opacity(0.15), in: Circle())
                            }
                        }
                        .disabled(isSyncing)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(white: 0.12, opacity: 0.7))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    )

                    // Storage and Quota breakdown
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Cloud Items")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text(subscriptionManager.syncUsage.isUnlimited ? "Unlimited" : "\(subscriptionManager.syncUsage.totalUsedItems) / \(subscriptionManager.syncUsage.maxAllowedItems)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(subscriptionManager.isQuotaExceeded ? .orange : .cyan)
                        }

                        if !subscriptionManager.syncUsage.isUnlimited {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 6)
                                    Capsule().fill(subscriptionManager.isQuotaExceeded ? Color.orange : Color.cyan)
                                        .frame(width: geo.size.width * subscriptionManager.quotaProgress, height: 6)
                                }
                            }
                            .frame(height: 6)
                        }

                        HStack {
                            Label("\(subscriptionManager.syncUsage.usedCalculations) Calculations", systemImage: "function")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Label("\(subscriptionManager.syncUsage.usedNotes) Notebooks", systemImage: "note.text")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(white: 0.10, opacity: 0.6))
                    )

                    // Banner for upgrade if on free tier
                    if !subscriptionManager.isPaid {
                        Button(action: { showPaywall = true }) {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.purple)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upgrade to Pro or Ultra")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Unlock unlimited sync, OTA signing & AI")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.purple)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.purple.opacity(0.12))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.purple.opacity(0.3), lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Account linking shortcut if guest
                    if authManager.isGuest {
                        Button(action: { showAccountSettings = true }) {
                            HStack {
                                Image(systemName: "link.badge.plus")
                                Text("Link Free Account to Sync Other Devices")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.cyan)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: { showAccountSettings = true }) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                Text("Manage Account & Preferences")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }

                    if let notice = syncNotice {
                        Text(notice)
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                    }

                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Cloud Synchronization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.cyan)
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showAccountSettings) {
                AccountSettingsView()
            }
            .sheet(isPresented: $showPaywall) {
                PaidPlansPaywallView()
            }
            .task {
                await subscriptionManager.fetchSubscriptionStatus()
            }
        }
    }

    private func handleSync() {
        isSyncing = true
        syncNotice = nil
        Task {
            _ = try? await syncManager.verifyDeviceToken()
            _ = try? await HistoryManager.shared.syncWithBackend()
            _ = try? await WorkspaceRepository.shared.syncWithBackend()
            await subscriptionManager.fetchSubscriptionStatus()
            await MainActor.run {
                self.isSyncing = false
                self.syncNotice = "Synced successfully at \(Date().formatted(date: .omitted, time: .standard))"
            }
        }
    }
}
