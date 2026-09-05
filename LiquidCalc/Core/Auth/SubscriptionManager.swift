//
//  SubscriptionManager.swift
//  LiquidCalc
//
//  Paid Plans, Entitlements, Cloud Sync Quotas & StoreKit/Promo Verification
//  Manages Free, Pro ($2.99/mo, $24.99/yr), and Ultra ($49.99 lifetime) tiers.
//  Created for LiquidCalc iOS 18+.
//

import Foundation

// MARK: - Subscription Tier

public enum SubscriptionTier: String, Codable, CaseIterable, Sendable {
    case free = "FREE"
    case pro = "PRO"
    case ultra = "ULTRA"

    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .ultra: return "Ultra"
        }
    }

    public var priceMonthlyDisplay: String {
        switch self {
        case .free: return "$0 Free"
        case .pro: return "$2.99 / mo"
        case .ultra: return "$49.99 Lifetime"
        }
    }

    public var priceAnnualDisplay: String {
        switch self {
        case .free: return "Free forever"
        case .pro: return "$24.99 / yr"
        case .ultra: return "$49.99 Lifetime"
        }
    }

    public var badgeLabel: String {
        switch self {
        case .free: return "Basic"
        case .pro: return "Most Popular"
        case .ultra: return "VIP Lifetime"
        }
    }

    public var isPaid: Bool {
        return self != .free
    }
}

// MARK: - Entitlements

public struct TierEntitlements: Codable, Sendable, Equatable {
    public let canOtaSign: Bool
    public let maxCloudSyncItems: Int // -1 = unlimited
    public let priorityAi: Bool
    public let allowCustomProfiles: Bool
    public let maxTweakInjections: Int
    public let exportFormats: [String]

    public var isUnlimitedSync: Bool {
        return maxCloudSyncItems == -1
    }

    public static let defaultFree = TierEntitlements(
        canOtaSign: false,
        maxCloudSyncItems: 50,
        priorityAi: false,
        allowCustomProfiles: false,
        maxTweakInjections: 3,
        exportFormats: ["TXT", "CSV"]
    )

    public static let defaultPro = TierEntitlements(
        canOtaSign: true,
        maxCloudSyncItems: -1,
        priorityAi: false,
        allowCustomProfiles: false,
        maxTweakInjections: 25,
        exportFormats: ["TXT", "CSV", "LaTeX", "PDF", "JSON"]
    )

    public static let defaultUltra = TierEntitlements(
        canOtaSign: true,
        maxCloudSyncItems: -1,
        priorityAi: true,
        allowCustomProfiles: true,
        maxTweakInjections: -1,
        exportFormats: ["TXT", "CSV", "LaTeX", "PDF", "JSON", "Markdown"]
    )

    public static func entitlements(for tier: SubscriptionTier) -> TierEntitlements {
        switch tier {
        case .free: return .defaultFree
        case .pro: return .defaultPro
        case .ultra: return .defaultUltra
        }
    }
}

// MARK: - Cloud Sync Usage

public struct CloudSyncUsage: Codable, Sendable, Equatable {
    public var usedCalculations: Int
    public var usedNotes: Int
    public var totalUsedItems: Int
    public var maxAllowedItems: Int
    public var isUnlimited: Bool
    public var remainingQuota: Int

    public static let defaultFree = CloudSyncUsage(
        usedCalculations: 0,
        usedNotes: 0,
        totalUsedItems: 0,
        maxAllowedItems: 50,
        isUnlimited: false,
        remainingQuota: 50
    )
}

// MARK: - Plan Model

public struct SubscriptionPlan: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let tier: SubscriptionTier
    public let priceUsd: Double
    public let billingPeriod: String
    public let description: String
    public let features: [String]

    public var priceFormatted: String {
        if priceUsd == 0 {
            return "Free"
        }
        if billingPeriod == "lifetime" {
            return String(format: "$%.2f Lifetime", priceUsd)
        }
        if billingPeriod == "annual" {
            return String(format: "$%.2f / yr", priceUsd)
        }
        return String(format: "$%.2f / mo", priceUsd)
    }

    public static let defaultCatalog: [SubscriptionPlan] = [
        SubscriptionPlan(
            id: "plan_free",
            name: "Free Tier",
            tier: .free,
            priceUsd: 0.00,
            billingPeriod: "free",
            description: "Local calculation power with starter cloud backup.",
            features: [
                "100% Anonymous Guest Mode",
                "Basic Cloud Sync (50 items quota)",
                "Standard Math Engine & Unit Converter",
                "Basic TXT / CSV Tape Export"
            ]
        ),
        SubscriptionPlan(
            id: "plan_pro_monthly",
            name: "Liquid Pro Monthly",
            tier: .pro,
            priceUsd: 2.99,
            billingPeriod: "monthly",
            description: "Unlimited cloud sync and over-the-air enterprise signing.",
            features: [
                "Unlimited Cloud Sync across all devices",
                "Over-The-Air (OTA) Sideloading & Signing",
                "Apple Vision OCR Math Scanner",
                "LaTeX, PDF & JSON Math Exports",
                "Up to 25 Tweak Dylib Injections"
            ]
        ),
        SubscriptionPlan(
            id: "plan_pro_annual",
            name: "Liquid Pro Annual",
            tier: .pro,
            priceUsd: 24.99,
            billingPeriod: "annual",
            description: "Full Pro features at a 30% discount over monthly.",
            features: [
                "All Pro Monthly features included",
                "Save 30% annually ($2.08 / month equivalent)",
                "Priority cloud sync bandwidth"
            ]
        ),
        SubscriptionPlan(
            id: "plan_ultra_lifetime",
            name: "Liquid Ultra VIP",
            tier: .ultra,
            priceUsd: 49.99,
            billingPeriod: "lifetime",
            description: "Lifetime VIP access to all premium features and Gemini AI.",
            features: [
                "Lifetime access (Single one-time payment)",
                "Unlimited Real-Time Cloud Sync",
                "Priority Gemini 2.5 Pro Multimodal AI",
                "Unlimited Over-The-Air Signing & Custom Profiles",
                "Unlimited Dylib Tweak Injections & Mach-O Tools",
                "VIP Discord / Fastlane Support"
            ]
        )
    ]
}

// MARK: - Action Results

public struct PromoRedeemResult: Sendable {
    public let success: Bool
    public let message: String
    public let tier: SubscriptionTier
    public let durationDays: Int
}

public struct UpgradeResult: Sendable {
    public let success: Bool
    public let tier: SubscriptionTier
    public let message: String
}

// MARK: - SubscriptionManager

@Observable
public final class SubscriptionManager: @unchecked Sendable {
    public static let shared = SubscriptionManager()

    public private(set) var currentTier: SubscriptionTier = .free
    public private(set) var entitlements: TierEntitlements = .defaultFree
    public private(set) var syncUsage: CloudSyncUsage = .defaultFree
    public private(set) var availablePlans: [SubscriptionPlan] = SubscriptionPlan.defaultCatalog
    public private(set) var isActiveSubscription: Bool = false
    public private(set) var isLoading: Bool = false
    public private(set) var isUpgrading: Bool = false
    public private(set) var errorMessage: String? = nil
    public private(set) var lastStatusCheck: Date? = nil

    private let tierStorageKey = "LiquidCalc_Subscription_Tier_v1"
    private let activeStatusKey = "LiquidCalc_Subscription_IsActive_v1"

    // MARK: - Computed Convenience Properties

    public var isPaid: Bool {
        return currentTier != .free
    }

    public var isProOrUltra: Bool {
        return currentTier == .pro || currentTier == .ultra
    }

    public var isUltra: Bool {
        return currentTier == .ultra
    }

    public var cloudSyncStatusPillText: String {
        switch currentTier {
        case .free:
            if AuthManager.shared.isGuest {
                return "Guest - Synced to Device"
            } else {
                return "Free - \(syncUsage.totalUsedItems)/\(syncUsage.maxAllowedItems) Synced"
            }
        case .pro:
            return "Pro - Cloud Synced"
        case .ultra:
            return "Ultra - VIP Synced"
        }
    }

    public var quotaProgress: Double {
        if syncUsage.isUnlimited { return 0.0 }
        let total = max(1, syncUsage.maxAllowedItems)
        return min(1.0, Double(syncUsage.totalUsedItems) / Double(total))
    }

    public var isQuotaExceeded: Bool {
        return !syncUsage.isUnlimited && syncUsage.totalUsedItems >= syncUsage.maxAllowedItems
    }

    public init() {
        loadPersistedTier()
    }

    private func loadPersistedTier() {
        if let stored = UserDefaults.standard.string(forKey: tierStorageKey),
           let tier = SubscriptionTier(rawValue: stored) {
            self.currentTier = tier
            self.entitlements = TierEntitlements.entitlements(for: tier)
        }
        self.isActiveSubscription = UserDefaults.standard.bool(forKey: activeStatusKey)
    }

    private func persistTier(_ tier: SubscriptionTier, isActive: Bool) {
        self.currentTier = tier
        self.isActiveSubscription = isActive
        self.entitlements = TierEntitlements.entitlements(for: tier)
        UserDefaults.standard.set(tier.rawValue, forKey: tierStorageKey)
        UserDefaults.standard.set(isActive, forKey: activeStatusKey)
    }

    // MARK: - Sync with Auth Session

    public func syncWithAuth(user: UserProfile) async {
        if let tier = SubscriptionTier(rawValue: user.tier.uppercased()) {
            await MainActor.run {
                self.persistTier(tier, isActive: tier != .free)
            }
        }
        await fetchSubscriptionStatus()
    }

    // MARK: - Fetch Public Plans

    public func fetchPlans() async {
        do {
            let (data, _) = try await CryptoTransport.shared.performEncryptedRequest(
                endpoint: "/api/plans",
                method: "GET"
            )

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let plansArray = json["plans"] as? [[String: Any]] {
                var loaded: [SubscriptionPlan] = []
                for p in plansArray {
                    guard let id = p["id"] as? String,
                          let name = p["name"] as? String,
                          let tierStr = p["tier"] as? String,
                          let tier = SubscriptionTier(rawValue: tierStr) else { continue }

                    let price = (p["priceUsd"] as? NSNumber)?.doubleValue ?? 0.0
                    let period = p["billingPeriod"] as? String ?? "monthly"
                    let desc = p["description"] as? String ?? ""
                    let feats = p["features"] as? [String] ?? []

                    loaded.append(SubscriptionPlan(
                        id: id,
                        name: name,
                        tier: tier,
                        priceUsd: price,
                        billingPeriod: period,
                        description: desc,
                        features: feats
                    ))
                }

                let finalPlans = loaded
                if !finalPlans.isEmpty {
                    await MainActor.run {
                        self.availablePlans = finalPlans
                    }
                }
            }
        } catch {
            // Keep fallback catalog on network failure
        }
    }

    // MARK: - Fetch Subscription & Quota Status

    @discardableResult
    public func fetchSubscriptionStatus() async -> Bool {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }

        let deviceId = DeviceSyncManager.shared.deviceId
        var endpoint = "/api/subscription/status?deviceId=\(deviceId)"
        if let user = AuthManager.shared.currentUser {
            endpoint += "&userId=\(user.id)"
        }

        do {
            let (data, _) = try await CryptoTransport.shared.performEncryptedRequest(
                endpoint: endpoint,
                method: "GET",
                headers: AuthManager.shared.authHeaders()
            )

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }

            let tierStr = json["tier"] as? String ?? "FREE"
            let tier = SubscriptionTier(rawValue: tierStr) ?? .free
            let isActive = json["isActiveSubscription"] as? Bool ?? (tier != .free)

            // Parse Cloud Sync Usage
            var usage = CloudSyncUsage.defaultFree
            if let usageJson = json["cloudSyncUsage"] as? [String: Any] {
                let calcs = usageJson["usedCalculations"] as? Int ?? 0
                let notes = usageJson["usedNotes"] as? Int ?? 0
                let total = usageJson["totalUsedItems"] as? Int ?? (calcs + notes)
                let maxAllowed = usageJson["maxAllowedItems"] as? Int ?? 50
                let isUnlimited = usageJson["isUnlimited"] as? Bool ?? (maxAllowed == -1)
                let remaining = usageJson["remainingQuota"] as? Int ?? (isUnlimited ? -1 : max(0, maxAllowed - total))

                usage = CloudSyncUsage(
                    usedCalculations: calcs,
                    usedNotes: notes,
                    totalUsedItems: total,
                    maxAllowedItems: maxAllowed,
                    isUnlimited: isUnlimited,
                    remainingQuota: remaining
                )
            }

            // Parse Entitlements if present
            var newEntitlements = TierEntitlements.entitlements(for: tier)
            if let entJson = json["entitlements"] as? [String: Any] {
                newEntitlements = TierEntitlements(
                    canOtaSign: entJson["canOtaSign"] as? Bool ?? (tier != .free),
                    maxCloudSyncItems: entJson["maxCloudSyncItems"] as? Int ?? (tier == .free ? 50 : -1),
                    priorityAi: entJson["priorityAi"] as? Bool ?? (tier == .ultra),
                    allowCustomProfiles: entJson["allowCustomProfiles"] as? Bool ?? (tier == .ultra),
                    maxTweakInjections: entJson["maxTweakInjections"] as? Int ?? (tier == .free ? 3 : (tier == .pro ? 25 : -1)),
                    exportFormats: entJson["exportFormats"] as? [String] ?? newEntitlements.exportFormats
                )
            }

            let finalEntitlements = newEntitlements
            let finalUsage = usage

            await MainActor.run {
                self.persistTier(tier, isActive: isActive)
                self.entitlements = finalEntitlements
                self.syncUsage = finalUsage
                self.lastStatusCheck = Date()
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            return false
        }
    }

    // MARK: - Promo Code Redemption

    public func redeemPromoCode(code: String) async throws -> PromoRedeemResult {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanCode.isEmpty else {
            throw CryptoTransportError.serializationError("Please enter a valid promo code.")
        }

        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }

        var payload: [String: Any] = [
            "code": cleanCode,
            "deviceId": DeviceSyncManager.shared.deviceId
        ]
        if let user = AuthManager.shared.currentUser {
            payload["userId"] = user.id
        }

        let (data, _) = try await CryptoTransport.shared.performEncryptedRequest(
            endpoint: "/api/subscription/promo",
            method: "POST",
            jsonPayload: payload,
            headers: AuthManager.shared.authHeaders()
        )

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool, success else {
            let errorMsg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String ?? "Invalid promo code"
            throw CryptoTransportError.invalidResponse(400, errorMsg)
        }

        let tierStr = json["tier"] as? String ?? "PRO"
        let grantedTier = SubscriptionTier(rawValue: tierStr) ?? .pro
        let duration = json["durationDays"] as? Int ?? 30
        let message = json["message"] as? String ?? "Promo code redeemed successfully!"

        await MainActor.run {
            self.persistTier(grantedTier, isActive: true)
        }

        await fetchSubscriptionStatus()

        return PromoRedeemResult(
            success: true,
            message: message,
            tier: grantedTier,
            durationDays: duration
        )
    }

    // MARK: - Subscription Upgrade (StoreKit / Mock)

    public func upgradeSubscription(
        tier: SubscriptionTier,
        billingPeriod: String = "monthly",
        provider: String = "mock",
        receipt: String? = nil
    ) async throws -> UpgradeResult {
        await MainActor.run {
            self.isUpgrading = true
            self.errorMessage = nil
        }

        defer {
            Task { @MainActor in
                self.isUpgrading = false
            }
        }

        let receiptString = receipt ?? "mock_receipt_\(tier.rawValue.lowercased())_\(billingPeriod.lowercased())_\(Int64(Date().timeIntervalSince1970))"
        let planId = tier == .ultra ? "plan_ultra_lifetime" : (billingPeriod == "annual" ? "plan_pro_annual" : "plan_pro_monthly")

        var payload: [String: Any] = [
            "receipt": receiptString,
            "provider": provider,
            "tier": tier.rawValue,
            "billingPeriod": billingPeriod,
            "planId": planId,
            "deviceId": DeviceSyncManager.shared.deviceId
        ]
        if let user = AuthManager.shared.currentUser {
            payload["userId"] = user.id
        }

        let (data, _) = try await CryptoTransport.shared.performEncryptedRequest(
            endpoint: "/api/subscription/verify",
            method: "POST",
            jsonPayload: payload,
            headers: AuthManager.shared.authHeaders()
        )

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let valid = json["valid"] as? Bool, valid else {
            let errorMsg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String ?? "Subscription verification failed"
            throw CryptoTransportError.invalidResponse(400, errorMsg)
        }

        let tierStr = json["tier"] as? String ?? tier.rawValue
        let activeTier = SubscriptionTier(rawValue: tierStr) ?? tier

        await MainActor.run {
            self.persistTier(activeTier, isActive: true)
        }

        await fetchSubscriptionStatus()

        return UpgradeResult(
            success: true,
            tier: activeTier,
            message: "Successfully activated \(activeTier.displayName) plan!"
        )
    }
}
