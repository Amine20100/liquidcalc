//
//  PaidPlansPaywallView.swift
//  LiquidCalc
//
//  Modern Frosted Glass Paywall
//  Displays Free, Pro ($2.99/mo or $24.99/yr), and Ultra ($49.99 lifetime) tiers.
//  Includes feature comparisons, 1-tap upgrade buttons, and promo code redemption.
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

public struct PaidPlansPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var subscriptionManager = SubscriptionManager.shared
    @Bindable private var authManager = AuthManager.shared

    @State private var selectedPeriod: BillingPeriod = .monthly
    @State private var promoCodeInput: String = ""
    @State private var promoStatusMessage: String? = nil
    @State private var promoIsSuccess: Bool = false
    @State private var isRedeemingPromo: Bool = false
    @State private var upgradeSuccessAlert: Bool = false
    @State private var upgradeErrorMessage: String? = nil

    enum BillingPeriod: String, CaseIterable {
        case monthly = "Monthly"
        case annual = "Annual (Save 30%)"
        case lifetime = "Lifetime VIP"
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Frosted Dark Glass Background
                Color(red: 0.05, green: 0.06, blue: 0.10)
                    .ignoresSafeArea()

                // Subtle Radial Ambient Glow
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.cyan.opacity(0.18),
                        Color.purple.opacity(0.12),
                        Color.clear
                    ]),
                    center: .top,
                    startRadius: 40,
                    endRadius: 420
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header
                        headerSection

                        // Billing Period Picker
                        billingPeriodPicker

                        // Pricing Cards
                        VStack(spacing: 16) {
                            if selectedPeriod == .lifetime {
                                ultraLifetimeCard
                                proMonthlyCard
                                freeCard
                            } else {
                                proMonthlyCard
                                ultraLifetimeCard
                                freeCard
                            }
                        }

                        // Feature Comparison Table
                        featureComparisonSection

                        // Promo Code Section
                        promoCodeSection

                        // Restore & Guarantee Footer
                        footerSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .alert("Upgrade Activated!", isPresented: $upgradeSuccessAlert) {
                Button("Done", role: .cancel) { dismiss() }
            } message: {
                Text("Your \(subscriptionManager.currentTier.displayName) plan is now active! All premium features are unlocked.")
            }
            .alert("Upgrade Error", isPresented: Binding(
                get: { upgradeErrorMessage != nil },
                set: { if !$0 { upgradeErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { upgradeErrorMessage = nil }
            } message: {
                Text(upgradeErrorMessage ?? "Unable to complete upgrade. Please try again.")
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Text("Upgrade LiquidCalc")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            Text("Unlock unlimited cross-device cloud sync, over-the-air enterprise app signing, and multimodal AI.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            if subscriptionManager.isPaid {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("Currently Active: \(subscriptionManager.currentTier.displayName) Plan")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.15))
                .clipShape(Capsule())
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Billing Period Switcher

    private var billingPeriodPicker: some View {
        Picker("Billing", selection: $selectedPeriod) {
            ForEach(BillingPeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 4)
    }

    // MARK: - Pro Card

    private var proMonthlyCard: some View {
        let isAnnual = selectedPeriod == .annual
        let isCurrent = subscriptionManager.currentTier == .pro

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Liquid Pro")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("POPULAR")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.cyan))
                    }
                    Text(isAnnual ? "$24.99 / year ($2.08/mo)" : "$2.99 / month")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.cyan)
                }
                Spacer()
                if isCurrent {
                    Text("CURRENT PLAN")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().stroke(Color.green, lineWidth: 1))
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                featureCheckRow("Unlimited Cloud Sync across all Apple devices", icon: "icloud.fill")
                featureCheckRow("Over-The-Air (OTA) Sideloading & Signing", icon: "arrow.down.app.fill")
                featureCheckRow("Apple Vision OCR Math Scanning", icon: "viewfinder")
                featureCheckRow("LaTeX, PDF, & JSON Math Exports", icon: "doc.text.fill")
                featureCheckRow("Up to 25 Tweak Dylib Injections", icon: "gearshape.2.fill")
            }

            Button(action: {
                Task {
                    await handleUpgrade(tier: .pro, billing: isAnnual ? "annual" : "monthly")
                }
            }) {
                HStack {
                    if subscriptionManager.isUpgrading {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "bolt.fill")
                        Text(isCurrent ? "Current Plan Active" : (isAnnual ? "Upgrade to Pro Annual ($24.99)" : "Upgrade to Pro ($2.99/mo)"))
                    }
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    LinearGradient(colors: [.cyan, Color(red: 0.2, green: 0.7, blue: 1.0)], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Color.cyan.opacity(0.35), radius: 8)
            }
            .buttonStyle(.plain)
            .disabled(isCurrent || subscriptionManager.isUpgrading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.12, opacity: 0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(LinearGradient(colors: [.cyan.opacity(0.8), .purple.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                )
        )
    }

    // MARK: - Ultra Lifetime Card

    private var ultraLifetimeCard: some View {
        let isCurrent = subscriptionManager.currentTier == .ultra

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Liquid Ultra VIP")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("LIFETIME VIP")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.purple))
                    }
                    Text("$49.99 One-Time Payment")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.purple)
                }
                Spacer()
                if isCurrent {
                    Text("ACTIVE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().stroke(Color.green, lineWidth: 1))
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                featureCheckRow("Everything in Pro, forever (no recurring fees)", icon: "infinity")
                featureCheckRow("Priority Gemini 2.5 Pro Multimodal AI Solver", icon: "brain.head.profile")
                featureCheckRow("Unlimited Over-The-Air Signing & Custom Profiles", icon: "signature")
                featureCheckRow("Real-Time Instant Cloud Sync (Zero latency)", icon: "bolt.horizontal.icloud.fill")
                featureCheckRow("Unlimited Tweak Injections & Mach-O Disassembler", icon: "cpu")
            }

            Button(action: {
                Task {
                    await handleUpgrade(tier: .ultra, billing: "lifetime")
                }
            }) {
                HStack {
                    if subscriptionManager.isUpgrading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "crown.fill")
                        Text(isCurrent ? "Ultra Lifetime Active" : "Get Ultra Lifetime ($49.99)")
                    }
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    LinearGradient(colors: [.purple, Color(red: 0.6, green: 0.2, blue: 0.9)], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Color.purple.opacity(0.4), radius: 8)
            }
            .buttonStyle(.plain)
            .disabled(isCurrent || subscriptionManager.isUpgrading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.12, opacity: 0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(LinearGradient(colors: [.purple.opacity(0.9), .pink.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                )
        )
    }

    // MARK: - Free Plan Card

    private var freeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Starter (Guest Mode)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text("Free Forever")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            VStack(alignment: .leading, spacing: 5) {
                featureCheckRow("100% Anonymous out-of-the-box (no login needed)", icon: "person.crop.circle")
                featureCheckRow("Basic Cloud Sync quota (50 calculations & notes)", icon: "cloud")
                featureCheckRow("Standard math evaluator & scientific modes", icon: "function")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.08, opacity: 0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Feature Comparison Section

    private var featureComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feature Comparison")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            VStack(spacing: 8) {
                comparisonRow("Cloud Sync Quota", free: "50 items", pro: "Unlimited", ultra: "Unlimited")
                comparisonRow("OTA Sideloading", free: "None", pro: "Enterprise", ultra: "Custom VIP")
                comparisonRow("AI Math Assistant", free: "Standard", pro: "Fast OCR", ultra: "Gemini 2.5 Pro")
                comparisonRow("Export Formats", free: "TXT, CSV", pro: "PDF, LaTeX", ultra: "All Formats")
                comparisonRow("Tweak Injections", free: "3 / session", pro: "25 / session", ultra: "Unlimited")
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(white: 0.09, opacity: 0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }

    private func comparisonRow(_ title: String, free: String, pro: String, ultra: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(free)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 68, alignment: .center)

            Text(pro)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.cyan)
                .frame(width: 68, alignment: .center)

            Text(ultra)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.purple)
                .frame(width: 80, alignment: .center)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Promo Code Section

    private var promoCodeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Have a Promo Code?")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            HStack(spacing: 8) {
                TextField("e.g. PROMO_ULTRA_VIP", text: $promoCodeInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

                Button(action: handleRedeemPromo) {
                    HStack {
                        if isRedeemingPromo {
                            ProgressView().tint(.white)
                        } else {
                            Text("Redeem")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(Color.cyan.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.6), lineWidth: 1))
                }
                .disabled(promoCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRedeemingPromo)
            }

            if let msg = promoStatusMessage {
                HStack(spacing: 4) {
                    Image(systemName: promoIsSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(promoIsSuccess ? .green : .orange)
                    Text(msg)
                        .font(.system(size: 12))
                        .foregroundColor(promoIsSuccess ? .green : .orange)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.10, opacity: 0.6))
        )
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Button("Restore Purchases") {
                    Task {
                        await subscriptionManager.fetchSubscriptionStatus()
                        if subscriptionManager.isPaid {
                            upgradeSuccessAlert = true
                        }
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(.cyan)

                Text("•").foregroundColor(.white.opacity(0.3))

                Link("Terms of Use", destination: URL(string: "https://liquidcalc.app/terms")!)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))

                Text("•").foregroundColor(.white.opacity(0.3))

                Link("Privacy Policy", destination: URL(string: "https://liquidcalc.app/privacy")!)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }

            Text("Subscriptions renew automatically unless cancelled at least 24 hours prior to end of period. Purchases apply to all devices via Guest Sync or Account Link.")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.35))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }

    private func featureCheckRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.cyan)
                .frame(width: 18)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    // MARK: - Handlers

    private func handleUpgrade(tier: SubscriptionTier, billing: String) async {
        do {
            _ = try await subscriptionManager.upgradeSubscription(tier: tier, billingPeriod: billing)
            upgradeSuccessAlert = true
        } catch {
            upgradeErrorMessage = error.localizedDescription
        }
    }

    private func handleRedeemPromo() {
        guard !promoCodeInput.isEmpty else { return }
        isRedeemingPromo = true
        promoStatusMessage = nil

        Task {
            do {
                let result = try await subscriptionManager.redeemPromoCode(code: promoCodeInput)
                promoIsSuccess = true
                promoStatusMessage = "\(result.message) (\(result.tier.displayName) tier for \(result.durationDays) days)"
                promoCodeInput = ""
                upgradeSuccessAlert = true
            } catch {
                promoIsSuccess = false
                promoStatusMessage = error.localizedDescription
            }
            isRedeemingPromo = false
        }
    }
}
