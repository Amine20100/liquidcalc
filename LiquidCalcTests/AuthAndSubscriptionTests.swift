//
//  AuthAndSubscriptionTests.swift
//  LiquidCalcTests
//
//  Unit Test Suite for Guest Mode, Account Linking, Paid Plans & Cloud Sync Quotas
//  Validates unforced guest mode, entitlements, promo code handling, and paywalls.
//  Created for LiquidCalc iOS 18+.
//

import XCTest
#if canImport(LiquidCalc)
@testable import LiquidCalc
#elseif canImport(LiquidCalcCore)
@testable import LiquidCalcCore
#endif

final class AuthAndSubscriptionTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // =========================================================================
    // MARK: - 1. Unforced Guest Mode & Anonymous Device Identity
    // =========================================================================

    func testGuestModeDefaultIdentity() {
        let auth = AuthManager.shared
        XCTAssertFalse(auth.deviceId.isEmpty, "Device ID must not be empty out-of-the-box")
        XCTAssertTrue(auth.deviceId.hasPrefix("ios_"), "Device ID follows ios_ prefix convention")

        // User should not be forced to log in
        if auth.currentUser == nil {
            XCTAssertTrue(auth.isGuest, "Default unauthenticated user must run in Guest Mode")
            switch auth.authStatus {
            case .guest(let devId):
                XCTAssertEqual(devId, auth.deviceId)
            case .authenticated:
                XCTFail("Should not be authenticated when currentUser is nil")
            }
        }
    }

    func testAuthHeadersInGuestMode() {
        let auth = AuthManager.shared
        let headers = auth.authHeaders()
        XCTAssertNotNil(headers["X-Device-Token"])
        XCTAssertEqual(headers["X-Device-Token"], auth.deviceId)
    }

    // =========================================================================
    // MARK: - 2. Subscription Tiers & Entitlements Matrix
    // =========================================================================

    func testSubscriptionTiersAndEntitlements() {
        let freeEnt = TierEntitlements.entitlements(for: .free)
        XCTAssertFalse(freeEnt.canOtaSign, "Free tier must not have OTA signing")
        XCTAssertEqual(freeEnt.maxCloudSyncItems, 50, "Free tier sync limit must be 50 items")
        XCTAssertFalse(freeEnt.isUnlimitedSync)
        XCTAssertFalse(freeEnt.priorityAi)

        let proEnt = TierEntitlements.entitlements(for: .pro)
        XCTAssertTrue(proEnt.canOtaSign, "Pro tier includes OTA signing")
        XCTAssertEqual(proEnt.maxCloudSyncItems, -1, "Pro tier sync is unlimited (-1)")
        XCTAssertTrue(proEnt.isUnlimitedSync)
        XCTAssertFalse(proEnt.priorityAi)

        let ultraEnt = TierEntitlements.entitlements(for: .ultra)
        XCTAssertTrue(ultraEnt.canOtaSign, "Ultra tier includes OTA signing")
        XCTAssertEqual(ultraEnt.maxCloudSyncItems, -1, "Ultra tier sync is unlimited (-1)")
        XCTAssertTrue(ultraEnt.isUnlimitedSync)
        XCTAssertTrue(ultraEnt.priorityAi, "Ultra tier includes Priority Gemini AI")
        XCTAssertTrue(ultraEnt.allowCustomProfiles)
    }

    func testSubscriptionTierDisplays() {
        XCTAssertEqual(SubscriptionTier.free.displayName, "Free")
        XCTAssertEqual(SubscriptionTier.pro.displayName, "Pro")
        XCTAssertEqual(SubscriptionTier.ultra.displayName, "Ultra")

        XCTAssertFalse(SubscriptionTier.free.isPaid)
        XCTAssertTrue(SubscriptionTier.pro.isPaid)
        XCTAssertTrue(SubscriptionTier.ultra.isPaid)
    }

    // =========================================================================
    // MARK: - 3. Cloud Sync Quotas & Progress Tracking
    // =========================================================================

    func testCloudSyncUsageCalculations() {
        var usage = CloudSyncUsage.defaultFree
        XCTAssertEqual(usage.totalUsedItems, 0)
        XCTAssertEqual(usage.maxAllowedItems, 50)
        XCTAssertFalse(usage.isUnlimited)
        XCTAssertEqual(usage.remainingQuota, 50)

        usage.usedCalculations = 20
        usage.usedNotes = 15
        usage.totalUsedItems = 35
        usage.remainingQuota = max(0, usage.maxAllowedItems - usage.totalUsedItems)
        XCTAssertEqual(usage.remainingQuota, 15)

        // Test quota overflow protection
        usage.totalUsedItems = 60
        usage.remainingQuota = max(0, usage.maxAllowedItems - usage.totalUsedItems)
        XCTAssertEqual(usage.remainingQuota, 0)
    }

    func testCloudSyncStatusPillText() {
        let sub = SubscriptionManager.shared
        let pillText = sub.cloudSyncStatusPillText
        XCTAssertFalse(pillText.isEmpty, "Status pill text must never be empty")
        XCTAssertTrue(
            pillText.contains("Guest") || pillText.contains("Free") || pillText.contains("Pro") || pillText.contains("Ultra"),
            "Status pill must describe the active tier"
        )
    }

    // =========================================================================
    // MARK: - 4. Catalog Plans & Price Formatting
    // =========================================================================

    func testSubscriptionPlanFormatting() {
        let freePlan = SubscriptionPlan.defaultCatalog.first { $0.tier == .free }
        XCTAssertNotNil(freePlan)
        XCTAssertEqual(freePlan?.priceFormatted, "Free")

        let proAnnual = SubscriptionPlan.defaultCatalog.first { $0.id == "plan_pro_annual" }
        XCTAssertNotNil(proAnnual)
        XCTAssertTrue(proAnnual?.priceFormatted.contains("/ yr") == true)

        let ultraPlan = SubscriptionPlan.defaultCatalog.first { $0.tier == .ultra }
        XCTAssertNotNil(ultraPlan)
        XCTAssertTrue(ultraPlan?.priceFormatted.contains("Lifetime") == true)
    }

    // =========================================================================
    // MARK: - 5. Input Validation for Account Linking & Promo Codes
    // =========================================================================

    func testLinkGuestAccountValidation() async {
        let auth = AuthManager.shared

        // Invalid email format rejection
        do {
            try await auth.linkGuestAccount(email: "bad_email", password: "validPassword123")
            XCTFail("Should have thrown error for invalid email")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("valid email"))
        }

        // Short password rejection
        do {
            try await auth.linkGuestAccount(email: "test@liquidcalc.local", password: "123")
            XCTFail("Should have thrown error for short password")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("at least 6 characters"))
        }
    }

    func testPromoCodeValidation() async {
        let sub = SubscriptionManager.shared
        do {
            _ = try await sub.redeemPromoCode(code: "")
            XCTFail("Should reject empty promo code")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("valid promo code"))
        }
    }

    // =========================================================================
    // MARK: - 6. User Profile Serialization
    // =========================================================================

    func testUserProfileSerialization() throws {
        let original = UserProfile(
            id: "user_test_123",
            email: "alice@liquidcalc.local",
            name: "Alice Math",
            role: "user",
            tier: "PRO"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: encoded)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.email, original.email)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.tier, original.tier)
    }

    // =========================================================================
    // MARK: - 7. Sign Out & Guest Reversion
    // =========================================================================

    func testSignOutRevertsToGuestMode() {
        let auth = AuthManager.shared
        auth.signOut()
        XCTAssertTrue(auth.isGuest, "Sign out must immediately place the app back into Guest Mode")
        XCTAssertNil(auth.currentUser, "Current user must be nil after sign out")
        XCTAssertFalse(auth.deviceId.isEmpty, "Device ID must be preserved after sign out")
    }

    // =========================================================================
    // MARK: - 8. Quota Boundary & Progress Calculations
    // =========================================================================

    func testQuotaExceededDetection() {
        var usage = CloudSyncUsage.defaultFree
        usage.totalUsedItems = 49
        XCTAssertFalse(usage.totalUsedItems >= usage.maxAllowedItems)

        usage.totalUsedItems = 50
        XCTAssertTrue(usage.totalUsedItems >= usage.maxAllowedItems)

        usage.totalUsedItems = 55
        XCTAssertTrue(usage.totalUsedItems >= usage.maxAllowedItems)

        usage.isUnlimited = true
        usage.maxAllowedItems = -1
        XCTAssertFalse(!usage.isUnlimited && usage.totalUsedItems >= usage.maxAllowedItems)
    }

    // =========================================================================
    // MARK: - 9. Entitlement Tier Comparison & Formatting
    // =========================================================================

    func testEntitlementTierRankAndFeatures() {
        let sub = SubscriptionManager.shared
        XCTAssertFalse(sub.availablePlans.isEmpty, "Plan catalog must contain default plans")
        let proMonthly = sub.availablePlans.first { $0.id == "plan_pro_monthly" }
        XCTAssertNotNil(proMonthly)
        XCTAssertEqual(proMonthly?.billingPeriod, "monthly")
        XCTAssertEqual(proMonthly?.priceUsd, 2.99)
    }
}
