//
//  AccountSettingsView.swift
//  LiquidCalc
//
//  Guest Identity, Account Linking & Cloud Synchronization Hub
//  Login is NOT forced: Users enjoy full anonymous calculator functionality.
//  Seamlessly links guest devices to registered accounts without data loss.
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

public struct AccountSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var authManager = AuthManager.shared
    @Bindable private var subscriptionManager = SubscriptionManager.shared
    @Bindable private var syncManager = DeviceSyncManager.shared

    public enum AuthMode: String, CaseIterable, Sendable {
        case link = "Link Device"
        case login = "Sign In"
        case register = "Create Account"
    }

    // Form inputs for Authentication & Guest Account Linking
    @State private var authMode: AuthMode = .link
    @State private var emailInput: String = ""
    @State private var passwordInput: String = ""
    @State private var nameInput: String = ""
    @State private var linkSuccessMessage: String? = nil
    @State private var linkErrorMessage: String? = nil
    @State private var diagnosticDetails: String? = nil
    @State private var showPaywall: Bool = false
    @State private var isSyncingNow: Bool = false
    @State private var syncStatusBanner: String? = nil

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.11)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Current Identity Card
                        identityCard

                        // Cloud Sync Quota Status
                        syncQuotaCard

                        // Account Linking (if Guest) or Account Info (if Authenticated)
                        if authManager.isGuest {
                            linkGuestAccountSection
                        } else {
                            authenticatedUserSection
                        }

                        // Active Plan & Subscription Management
                        subscriptionCard

                        // Device Diagnostics Card
                        deviceDiagnosticsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle("Account & Cloud Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.cyan)
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaidPlansPaywallView()
            }
            .task {
                await subscriptionManager.fetchSubscriptionStatus()
            }
        }
    }

    // MARK: - Identity Card

    private var identityCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: authManager.isGuest ? [.cyan.opacity(0.3), .blue.opacity(0.2)] : [.purple.opacity(0.4), .cyan.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .overlay(Circle().stroke(Color.cyan.opacity(0.5), lineWidth: 1.5))

                Image(systemName: authManager.isGuest ? "person.crop.circle" : "person.badge.shield.checkmark.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.cyan)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(authManager.isGuest ? "Guest Device" : (authManager.currentUser?.name ?? "Registered User"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(subscriptionManager.currentTier.rawValue)
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(subscriptionManager.isPaid ? Color.purple : Color.cyan)
                        )
                }

                if authManager.isGuest {
                    Text("Anonymous Mode • No Login Required")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                } else if let email = authManager.currentUser?.email {
                    Text(email)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.75))
                }
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.12, opacity: 0.7))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
    }

    // MARK: - Cloud Sync Quota Card

    private var syncQuotaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Cloud Synchronization", systemImage: "icloud.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.cyan)
                Spacer()
                Button(action: handleSyncNow) {
                    HStack(spacing: 4) {
                        if isSyncingNow {
                            ProgressView().scaleEffect(0.7).tint(.cyan)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11))
                        }
                        Text(isSyncingNow ? "Syncing..." : "Sync Now")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.15))
                    .foregroundColor(.cyan)
                    .clipShape(Capsule())
                }
                .disabled(isSyncingNow)
            }

            // Quota Bar
            if subscriptionManager.syncUsage.isUnlimited {
                HStack(spacing: 8) {
                    Image(systemName: "infinity")
                        .foregroundColor(.purple)
                        .font(.system(size: 16, weight: .bold))
                    Text("Unlimited Cloud Sync Active across all your devices")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Usage: \(subscriptionManager.syncUsage.totalUsedItems) of \(subscriptionManager.syncUsage.maxAllowedItems) items")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text("\(subscriptionManager.syncUsage.remainingQuota) remaining")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(subscriptionManager.isQuotaExceeded ? .orange : .cyan)
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 8)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: subscriptionManager.isQuotaExceeded ? [.orange, .red] : [.cyan, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * subscriptionManager.quotaProgress, height: 8)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text("Calculations: \(subscriptionManager.syncUsage.usedCalculations)")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.3))
                        Text("Notebooks: \(subscriptionManager.syncUsage.usedNotes)")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }

            if let banner = syncStatusBanner {
                Text(banner)
                    .font(.system(size: 11))
                    .foregroundColor(.green)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.12, opacity: 0.7))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
    }

    // MARK: - Authentication & Guest Account Linking Section (Unforced Guest Mode)

    private var linkGuestAccountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Mode Selector: Link Device / Sign In / Create Account
            Picker("Authentication Mode", selection: $authMode) {
                ForEach(AuthMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: authMode == .link ? "link.badge.plus" : (authMode == .login ? "person.crop.circle.badge.checkmark" : "person.badge.plus"))
                        .foregroundColor(.cyan)
                    Text(authMode == .link ? "Link to Permanent Account" : (authMode == .login ? "Sign In with Existing Account" : "Create Permanent Account"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Text(authModeDescription)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.68))
                    .lineSpacing(2)
            }

            VStack(spacing: 10) {
                if authMode != .login {
                    TextField("Your Name (optional)", text: $nameInput)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }

                TextField("Email Address", text: $emailInput)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

                SecureField("Password (min 6 characters)", text: $passwordInput)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }

            if let error = linkErrorMessage {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: error.lowercased().contains("network") || error.lowercased().contains("offline") || error.lowercased().contains("reach") ? "wifi.exclamationmark" : "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connection Diagnostic")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 11))
                        Text("Guest Mode Active: All math, notes & local data remain 100% saved on this device.")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.green.opacity(0.9))
                    }
                    .padding(.top, 2)
                }
                .padding(10)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.35), lineWidth: 1))
            }

            if let success = linkSuccessMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                    Text(success)
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
                .padding(8)
                .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            Button(action: handleSubmitAuth) {
                HStack(spacing: 6) {
                    if authManager.isLoading {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: authMode == .link ? "arrow.triangle.merge" : (authMode == .login ? "arrow.right.circle.fill" : "person.badge.plus"))
                        Text(authSubmitButtonTitle)
                    }
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color.cyan)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(authManager.isLoading || emailInput.isEmpty || passwordInput.count < 6)

            // Unforced Guest Mode reassurance
            HStack(spacing: 5) {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.white.opacity(0.4))
                    .font(.system(size: 10))
                Text("Login is never forced: LiquidCalc works fully anonymously.")
                    .font(.system(size: 10.5))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.12, opacity: 0.7))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
        )
    }

    private var authModeDescription: String {
        switch authMode {
        case .link:
            return "Sync your calculations & notes to your other devices. All current data is seamlessly preserved with zero loss."
        case .login:
            return "Access your existing account, restored entitlements, and cloud history across all your signed devices."
        case .register:
            return "Create a new free permanent account for unlimited multi-device cloud backup and synchronization."
        }
    }

    private var authSubmitButtonTitle: String {
        switch authMode {
        case .link:
            return "Link Device & Preserve All Data"
        case .login:
            return "Sign In to Account"
        case .register:
            return "Create Free Account"
        }
    }

    // MARK: - Authenticated User Section

    private var authenticatedUserSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Registered Account Details")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            if let user = authManager.currentUser {
                VStack(spacing: 8) {
                    detailRow("User ID", value: String(user.id.prefix(12)) + "...")
                    detailRow("Email", value: user.email)
                    if let name = user.name {
                        detailRow("Name", value: name)
                    }
                    detailRow("Role", value: user.role.capitalized)
                    detailRow("Account Tier", value: user.tier.uppercased())
                }
                .padding(12)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }

            Button(role: .destructive, action: {
                authManager.signOut()
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out to Anonymous Guest Mode")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.red.opacity(0.9))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.12, opacity: 0.7))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
    }

    // MARK: - Subscription Management Card

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Plan: \(subscriptionManager.currentTier.displayName)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(subscriptionManager.isPaid ? "Unlimited features unlocked" : "Basic features • Upgrade for unlimited sync & AI")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                Button(action: { showPaywall = true }) {
                    Text(subscriptionManager.isPaid ? "Change Plan" : "Upgrade")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            subscriptionManager.isPaid ? Color.purple.opacity(0.3) : Color.cyan.opacity(0.3)
                        )
                        .foregroundColor(subscriptionManager.isPaid ? .purple : .cyan)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(subscriptionManager.isPaid ? Color.purple.opacity(0.6) : Color.cyan.opacity(0.6), lineWidth: 1)
                        )
                }
            }

            Divider().background(Color.white.opacity(0.1))

            // Entitlements checklist
            VStack(alignment: .leading, spacing: 6) {
                entitlementCheck("Over-The-Air Sideloading", active: subscriptionManager.entitlements.canOtaSign)
                entitlementCheck("Gemini 2.5 Pro VIP AI", active: subscriptionManager.entitlements.priorityAi)
                entitlementCheck("Custom Provisioning Profiles", active: subscriptionManager.entitlements.allowCustomProfiles)
                entitlementCheck("Unlimited Cloud Sync", active: subscriptionManager.entitlements.isUnlimitedSync)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.12, opacity: 0.7))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
    }

    // MARK: - Device Diagnostics

    private var deviceDiagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Device Diagnostics")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))

            detailRow("Device ID", value: String(syncManager.deviceId.prefix(16)) + "...")
            detailRow("Device Verified", value: syncManager.isVerified ? "Yes (Secure Pipe)" : "Pending")
            if let last = syncManager.lastSyncDate {
                detailRow("Last Sync", value: last.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.08, opacity: 0.5))
        )
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    private func entitlementCheck(_ title: String, active: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: active ? "checkmark.circle.fill" : "lock.fill")
                .font(.system(size: 12))
                .foregroundColor(active ? .green : .white.opacity(0.3))
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(active ? .white.opacity(0.9) : .white.opacity(0.4))
        }
    }

    // MARK: - Actions

    private func handleSubmitAuth() {
        linkErrorMessage = nil
        linkSuccessMessage = nil

        switch authMode {
        case .link:
            handleLinkAccount()
        case .login:
            handleSignIn()
        case .register:
            handleRegister()
        }
    }

    private func handleSignIn() {
        Task {
            do {
                let user = try await authManager.login(
                    email: emailInput,
                    password: passwordInput
                )
                _ = try? await HistoryManager.shared.syncWithBackend()
                _ = try? await WorkspaceRepository.shared.syncWithBackend()
                await subscriptionManager.fetchSubscriptionStatus()
                linkSuccessMessage = "Welcome back, \(user.name ?? user.email)! Cloud sync and entitlements restored."
                emailInput = ""
                passwordInput = ""
            } catch {
                linkErrorMessage = error.localizedDescription
            }
        }
    }

    private func handleRegister() {
        Task {
            do {
                let user = try await authManager.register(
                    email: emailInput,
                    password: passwordInput,
                    name: nameInput.isEmpty ? nil : nameInput
                )
                _ = try? await HistoryManager.shared.syncWithBackend()
                _ = try? await WorkspaceRepository.shared.syncWithBackend()
                await subscriptionManager.fetchSubscriptionStatus()
                linkSuccessMessage = "Account created successfully for \(user.email)! Free multi-device cloud sync active."
                emailInput = ""
                passwordInput = ""
                nameInput = ""
            } catch {
                linkErrorMessage = error.localizedDescription
            }
        }
    }

    private func handleLinkAccount() {
        linkErrorMessage = nil
        linkSuccessMessage = nil

        Task {
            do {
                let result = try await authManager.linkGuestAccount(
                    email: emailInput,
                    password: passwordInput,
                    name: nameInput.isEmpty ? nil : nameInput
                )
                _ = try? await HistoryManager.shared.syncWithBackend()
                _ = try? await WorkspaceRepository.shared.syncWithBackend()
                await subscriptionManager.fetchSubscriptionStatus()
                linkSuccessMessage = "Account linked successfully! Preserved \(result.migratedCalculations) calculations and \(result.migratedNotes) notes."
                emailInput = ""
                passwordInput = ""
                nameInput = ""
            } catch {
                linkErrorMessage = error.localizedDescription
            }
        }
    }

    private func handleSyncNow() {
        isSyncingNow = true
        syncStatusBanner = nil

        Task {
            _ = try? await syncManager.verifyDeviceToken()
            _ = try? await HistoryManager.shared.syncWithBackend()
            _ = try? await WorkspaceRepository.shared.syncWithBackend()
            await subscriptionManager.fetchSubscriptionStatus()
            await MainActor.run {
                self.isSyncingNow = false
                self.syncStatusBanner = "Cloud state refreshed successfully at \(Date().formatted(date: .omitted, time: .standard))"
            }
        }
    }
}
